import type { ViewerProfile, ViewerWallet } from "../types";
import { assertClientFeatureAvailable } from "../platform/access";
import { ensureWebsiteSession } from "../lib/supabase";
import {
  asNumber,
  asString,
  ensureClient,
  maybeSingle,
  selectList,
  type JsonRecord,
} from "./apiClient";
import { normalizePhonePresetRow } from "./apiMappers";

export interface ViewerState {
  profile: ViewerProfile | null;
  wallet: ViewerWallet | null;
  walletTransactions: {
    id: string;
    title: string;
    amount: number;
    type: "earn" | "spend" | "transfer_sent" | "transfer_received";
    timestamp: number;
    dateStr: string;
  }[];
  notifications: {
    id: string;
    type: string;
    title: string;
    message: string;
    timestamp: number;
    read: boolean;
    data: Record<string, unknown>;
  }[];
}

export interface WebsitePhonePreset {
  countryCode: string | null;
  dialCode: string;
  hint: string;
  minDigits: number;
}

export interface CurrencyDisplayPreference {
  code: string;
  symbol: string;
  decimals: number;
  spaceSeparated: boolean;
  rate: number;
  fetPerEur: number | null;
}

function relativeDateLabel(timestamp: string): string {
  const date = new Date(timestamp);
  if (Number.isNaN(date.getTime())) return "Just now";
  const diff = Date.now() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  if (days > 0) return `${days}d ago`;
  if (hours > 0) return `${hours}h ago`;
  if (minutes > 0) return `${minutes}m ago`;
  return "Just now";
}

function resolveBrowserCountryCode(): string | null {
  if (typeof navigator === "undefined") return null;

  const locales = [
    navigator.language,
    ...(Array.isArray(navigator.languages) ? navigator.languages : []),
  ];

  for (const locale of locales) {
    const match = locale?.match(/[-_]([a-z]{2})$/i);
    if (match?.[1]) return match[1].toUpperCase();
  }

  return null;
}

export async function getViewerState(): Promise<ViewerState | null> {
  const client = await ensureClient();
  if (!client) return null;

  const userId = await ensureWebsiteSession();
  if (!userId) return null;

  try {
    const [profileRow, walletRow, txRows, notificationRows] = await Promise.all(
      [
        maybeSingle<JsonRecord>(
          client
            .from("profiles")
            .select(
              "user_id,fan_id,display_name,onboarding_completed,is_anonymous,auth_method",
            )
            .eq("user_id", userId)
            .maybeSingle(),
        ),
        maybeSingle<JsonRecord>(
          client
            .from("wallet_overview")
            .select("*")
            .eq("user_id", userId)
            .maybeSingle(),
        ),
        selectList<JsonRecord>(
          client
            .from("fet_wallet_transactions")
            .select("id,tx_type,direction,amount_fet,title,created_at")
            .order("created_at", { ascending: false })
            .limit(12),
        ),
        selectList<JsonRecord>(
          client
            .from("notification_log")
            .select("id,type,title,body,data,sent_at,read_at")
            .order("sent_at", { ascending: false })
            .limit(20),
        ),
      ],
    );

    const profile: ViewerProfile | null = profileRow
      ? {
          userId: asString(profileRow.user_id),
          fanId: asString(profileRow.fan_id, "------"),
          displayName:
            asString(profileRow.display_name) ||
            `Fan #${asString(profileRow.fan_id, "------")}`,
          onboardingCompleted: profileRow.onboarding_completed === true,
          isAnonymous: profileRow.is_anonymous === true,
          authMethod: asString(profileRow.auth_method, "anonymous"),
        }
      : null;

    const wallet: ViewerWallet | null = walletRow
      ? {
          availableBalanceFet: asNumber(walletRow.available_balance_fet),
          lockedBalanceFet: asNumber(walletRow.locked_balance_fet),
          fanId: asString(walletRow.fan_id) || null,
          displayName: asString(walletRow.display_name) || null,
        }
      : {
          availableBalanceFet: 0,
          lockedBalanceFet: 0,
          fanId: profile?.fanId ?? null,
          displayName: profile?.displayName ?? null,
        };

    return {
      profile,
      wallet,
      walletTransactions: txRows.map((row) => {
        const direction = asString(row.direction);
        const txType = asString(row.tx_type);
        const transferSent = txType === "transfer" && direction === "debit";
        const transferReceived =
          txType === "transfer" && direction === "credit";
        return {
          id: asString(row.id),
          title: asString(
            row.title,
            transferSent ? "Transfer sent" : "Wallet activity",
          ),
          amount: asNumber(row.amount_fet),
          type: transferSent
            ? "transfer_sent"
            : transferReceived
              ? "transfer_received"
              : direction === "credit"
                ? "earn"
                : "spend",
          timestamp: new Date(asString(row.created_at)).getTime(),
          dateStr: relativeDateLabel(asString(row.created_at)),
        };
      }),
      notifications: notificationRows.map((row) => ({
        id: asString(row.id),
        type: asString(row.type, "system"),
        title: asString(row.title),
        message: asString(row.body),
        timestamp: new Date(asString(row.sent_at)).getTime(),
        read: !!row.read_at,
        data: (row.data as Record<string, unknown> | null) ?? {},
      })),
    };
  } catch (error) {
    console.warn("Failed to load viewer state", error);
    return null;
  }
}

export async function getPreferredPhonePreset(): Promise<WebsitePhonePreset> {
  const client = await ensureClient();
  const browserCountryCode = resolveBrowserCountryCode();

  if (!client) {
    return {
      countryCode: browserCountryCode,
      dialCode: "+",
      hint: "000 000 000",
      minDigits: 7,
    };
  }

  try {
    if (browserCountryCode) {
      const directRow = await maybeSingle<JsonRecord>(
        client
          .from("phone_presets")
          .select("country_code,dial_code,hint,min_digits")
          .eq("country_code", browserCountryCode)
          .maybeSingle(),
      );
      if (directRow) return normalizePhonePresetRow(directRow);
    }

    const fallbackRows = await selectList<JsonRecord>(
      client
        .from("phone_presets")
        .select("country_code,dial_code,hint,min_digits")
        .order("country_code", { ascending: true })
        .limit(1),
    );

    if (fallbackRows[0]) return normalizePhonePresetRow(fallbackRows[0]);
  } catch (error) {
    console.warn("Failed to load phone presets", error);
  }

  return {
    countryCode: browserCountryCode,
    dialCode: "+",
    hint: "000 000 000",
    minDigits: 7,
  };
}

export async function getPreferredCurrencyDisplay(): Promise<CurrencyDisplayPreference> {
  const client = await ensureClient();
  const browserCountryCode = resolveBrowserCountryCode();

  if (!client) {
    return {
      code: "EUR",
      symbol: "€",
      decimals: 2,
      spaceSeparated: false,
      rate: 1,
      fetPerEur: null,
    };
  }

  try {
    let currencyCode = "EUR";

    if (browserCountryCode) {
      const countryCurrencyRow = await maybeSingle<JsonRecord>(
        client
          .from("country_currency_map")
          .select("currency_code")
          .eq("country_code", browserCountryCode)
          .maybeSingle(),
      );
      currencyCode = asString(countryCurrencyRow?.currency_code, "EUR");
    }

    const [pegRow, displayRow, rateRow] = await Promise.all([
      maybeSingle<JsonRecord>(
        client
          .from("app_config_remote")
          .select("value")
          .eq("key", "fet_per_eur")
          .maybeSingle(),
      ),
      maybeSingle<JsonRecord>(
        client
          .from("currency_display_metadata")
          .select("currency_code,symbol,decimals,space_separated")
          .eq("currency_code", currencyCode)
          .maybeSingle(),
      ),
      currencyCode === "EUR"
        ? Promise.resolve<JsonRecord | null>({ rate: 1 } as JsonRecord)
        : maybeSingle<JsonRecord>(
            client
              .from("currency_rates")
              .select("rate")
              .eq("base_currency", "EUR")
              .eq("target_currency", currencyCode)
              .maybeSingle(),
          ),
    ]);

    const fetPerEurCandidate = asNumber(pegRow?.value, 0);
    const fetPerEur = fetPerEurCandidate > 0 ? fetPerEurCandidate : null;

    if (displayRow) {
      return {
        code: asString(displayRow.currency_code, currencyCode),
        symbol: asString(displayRow.symbol, "€"),
        decimals: asNumber(displayRow.decimals, 2),
        spaceSeparated: displayRow.space_separated === true,
        rate: asNumber(rateRow?.rate, 1),
        fetPerEur,
      };
    }
  } catch (error) {
    console.warn("Failed to load currency display preference", error);
  }

  return {
    code: "EUR",
    symbol: "€",
    decimals: 2,
    spaceSeparated: false,
    rate: 1,
    fetPerEur: null,
  };
}

export async function transferFetByFanId(
  recipientFanId: string,
  amountFet: number,
): Promise<{
  success: boolean;
  viewerState?: ViewerState | null;
  error?: string;
}> {
  const client = await ensureClient();
  if (!client) {
    return {
      success: false,
      error: "Supabase is not configured for the website.",
    };
  }

  try {
    assertClientFeatureAvailable(
      "wallet",
      "Wallet transfers are currently unavailable.",
    );

    const { error } = await client.rpc("transfer_fet_by_fan_id", {
      p_recipient_fan_id: recipientFanId,
      p_amount_fet: amountFet,
    });
    if (error) {
      throw new Error(error.message);
    }

    return {
      success: true,
      viewerState: await getViewerState(),
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Transfer failed.",
    };
  }
}

export async function markNotificationRead(
  notificationId: string,
): Promise<void> {
  const client = await ensureClient();
  if (!client) return;

  try {
    assertClientFeatureAvailable(
      "notifications",
      "Notifications are currently unavailable.",
    );

    const { error } = await client.rpc("mark_notification_read", {
      p_notification_id: notificationId,
    });
    if (error) {
      throw error;
    }
  } catch (error) {
    console.warn(
      `Failed to mark notification ${notificationId} as read`,
      error,
    );
  }
}

export async function markAllNotificationsRead(): Promise<void> {
  const client = await ensureClient();
  if (!client) return;

  try {
    assertClientFeatureAvailable(
      "notifications",
      "Notifications are currently unavailable.",
    );

    const { error } = await client.rpc("mark_all_notifications_read");
    if (error) {
      throw error;
    }
  } catch (error) {
    console.warn("Failed to mark all notifications as read", error);
  }
}
