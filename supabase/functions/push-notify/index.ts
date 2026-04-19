// FANZONE — Push Notification Edge Function
// Sends FCM/APNs push notifications to user devices.
//
// Payload: { user_id, type, title, body, data? }
// Or batch: { user_ids: string[], type, title, body, data? }
//
// Auth: x-push-notify-secret only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

import {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedEdgeRequest,
} from "../_shared/http.ts";
import { parsePushPayload } from "./payload.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_SA_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
const PUSH_NOTIFY_SECRET = Deno.env.get("PUSH_NOTIFY_SECRET")?.trim() || "";

interface GoogleServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

interface DeviceToken {
  id: string;
  user_id: string;
  token: string;
  platform: string;
}

interface NotificationPreferenceRow {
  user_id: string;
  goal_alerts?: boolean | null;
  pool_updates?: boolean | null;
  daily_challenge?: boolean | null;
  wallet_activity?: boolean | null;
  community_news?: boolean | null;
  marketing?: boolean | null;
}

type NotificationPreferenceKey = Exclude<
  keyof NotificationPreferenceRow,
  "user_id"
>;

interface FirebaseMessage {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
  android?: {
    priority: string;
    notification: { sound: string; channel_id: string };
  };
  apns?: {
    payload: { aps: { sound: string; badge: number } };
  };
}

// ── Google OAuth2 token for FCM v1 ──

async function getAccessToken(
  serviceAccount: GoogleServiceAccount,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = btoa(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );

  const signatureInput = new TextEncoder().encode(`${header}.${claim}`);

  // Import private key
  const pemContent = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    signatureInput,
  );
  const encodedSig = btoa(
    String.fromCharCode(...new Uint8Array(signature)),
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${header}.${claim}.${encodedSig}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  if (!tokenRes.ok) {
    throw new Error(`OAuth token error: ${await tokenRes.text()}`);
  }

  const tokenData = await tokenRes.json();
  return tokenData.access_token;
}

// ── Send to single device ──

async function sendToDevice(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
  platform?: string,
): Promise<{ success: boolean; error?: string; stale?: boolean }> {
  const message: FirebaseMessage = {
    token,
    notification: { title, body },
    data: data || {},
  };

  // Platform-specific config
  if (platform === "android") {
    message.android = {
      priority: "high",
      notification: { sound: "default", channel_id: "fanzone_default" },
    };
  } else if (platform === "ios") {
    message.apns = {
      payload: { aps: { sound: "default", badge: 1 } },
    };
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    },
  );

  if (res.ok) {
    return { success: true };
  }

  const errorBody = await res.json().catch(() => ({}));
  const errorCode = errorBody?.error?.details?.[0]?.errorCode || "";

  // Token is stale/invalid — mark for removal
  if (
    res.status === 404 ||
    res.status === 410 ||
    errorCode === "UNREGISTERED"
  ) {
    return { success: false, error: "Token invalid", stale: true };
  }

  return {
    success: false,
    error: errorBody?.error?.message || `HTTP ${res.status}`,
  };
}

// ── Main handler ──

Deno.serve(async (req: Request) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: buildCorsHeaders(
        "authorization, content-type, x-push-notify-secret",
      ),
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (
    !isAuthorizedEdgeRequest({
      req,
      sharedSecrets: [{
        header: "x-push-notify-secret",
        value: PUSH_NOTIFY_SECRET,
      }],
    })
  ) {
    return new Response("Unauthorized", { status: 401 });
  }

  if (!GOOGLE_SA_JSON) {
    return Response.json(
      { error: "GOOGLE_SERVICE_ACCOUNT_JSON not configured" },
      { status: 500 },
    );
  }

  try {
    let payload;

    try {
      payload = parsePushPayload(await req.json());
    } catch (error) {
      return Response.json({ error: getErrorMessage(error) }, {
        status: 400,
      });
    }

    const { userIds, type, title, body, data } = payload;
    const serviceAccount = JSON.parse(GOOGLE_SA_JSON) as GoogleServiceAccount;
    const projectId = serviceAccount.project_id;
    const accessToken = await getAccessToken(serviceAccount);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Check notification preferences
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select(
        "user_id, goal_alerts, pool_updates, daily_challenge, wallet_activity, community_news, marketing",
      )
      .in("user_id", userIds);

    const prefRows = (prefs || []) as NotificationPreferenceRow[];
    const prefMap = new Map(
      prefRows.map((preference) => [preference.user_id, preference]),
    );

    // Filter based on notification type → preference column mapping
    const typeToColumn: Partial<Record<string, NotificationPreferenceKey>> = {
      goal: "goal_alerts",
      pool_settled: "pool_updates",
      pool_joined: "pool_updates",
      daily_challenge: "daily_challenge",
      wallet_credit: "wallet_activity",
      wallet_debit: "wallet_activity",
      community: "community_news",
      marketing: "marketing",
    };

    const prefColumn = typeToColumn[type];
    const eligibleUserIds = userIds.filter((uid) => {
      if (!prefColumn) return true; // unknown type → send
      const userPref = prefMap.get(uid);
      if (!userPref) return true; // no prefs → default on
      return userPref[prefColumn] !== false;
    });

    if (!eligibleUserIds.length) {
      return Response.json({
        sent: 0,
        skipped: userIds.length,
        reason: "opted_out",
      });
    }

    // Get device tokens
    const { data: tokens, error: tokenError } = await supabase
      .from("device_tokens")
      .select("id, user_id, token, platform")
      .in("user_id", eligibleUserIds)
      .eq("is_active", true);

    if (tokenError || !tokens?.length) {
      return Response.json({ sent: 0, no_tokens: true });
    }

    // Send to all devices
    let sent = 0;
    let failed = 0;
    const staleTokenIds: string[] = [];

    for (const deviceToken of tokens as DeviceToken[]) {
      const result = await sendToDevice(
        accessToken,
        projectId,
        deviceToken.token,
        title,
        body,
        data,
        deviceToken.platform,
      );

      if (result.success) {
        sent++;
      } else {
        failed++;
        if (result.stale) {
          staleTokenIds.push(deviceToken.id);
        }
      }
    }

    // Remove stale tokens
    if (staleTokenIds.length > 0) {
      await supabase
        .from("device_tokens")
        .update({ is_active: false })
        .in("id", staleTokenIds);
    }

    // Log notifications
    const logEntries = eligibleUserIds.map((uid) => ({
      user_id: uid,
      type,
      title,
      body,
      data: data || {},
    }));

    await supabase.from("notification_log").insert(logEntries);

    return Response.json({
      sent,
      failed,
      stale_tokens_removed: staleTokenIds.length,
      skipped: userIds.length - eligibleUserIds.length,
    });
  } catch (error: unknown) {
    console.error("Push notify error:", error);
    return Response.json({ error: getErrorMessage(error) }, { status: 500 });
  }
});
