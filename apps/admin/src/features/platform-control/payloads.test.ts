import { describe, expect, it } from "vitest";

import {
  buildPlatformContentBlockPayload,
  buildPlatformFeaturePayload,
} from "./payloads";

describe("platform control payload builders", () => {
  it("normalizes feature payloads for the admin RPC", () => {
    const payload = buildPlatformFeaturePayload({
      feature_key: " Pools ",
      display_name: "Pools",
      description: " Match pools ",
      status: "scheduled",
      is_enabled: true,
      navigation_group: " primary ",
      default_route_key: " /pools ",
      admin_notes: " launch soon ",
      metadata: { card_icon: "trophy" },
      auth_required: true,
      role_restrictions: { any_of: ["authenticated"] },
      dependency_config: { requires_all: ["fixtures", "wallet"] },
      rollout_config: { audience: "beta" },
      schedule_start_at: "2026-04-24T10:00:00.000Z",
      schedule_end_at: "2026-04-25T10:00:00.000Z",
      mobile_channel: {
        channel: "mobile",
        is_visible: true,
        is_enabled: true,
        show_in_navigation: true,
        show_on_home: true,
        sort_order: 30,
        route_key: " /pools ",
        entry_key: " pools.index ",
        navigation_label: " Pools ",
        placement_key: " primary-nav ",
        metadata: { icon: "trophy" },
      },
      web_channel: {
        channel: "web",
        is_visible: false,
        is_enabled: true,
        show_in_navigation: false,
        show_on_home: true,
        sort_order: 40,
        route_key: " /pools ",
        entry_key: " pools.web ",
        navigation_label: " Pools ",
        placement_key: " home-primary ",
        metadata: { variant: "hero" },
      },
    });

    expect(payload.feature_key).toBe("pools");
    expect(payload.default_route_key).toBe("/pools");
    expect(payload.mobile_channel.route_key).toBe("/pools");
    expect(payload.mobile_channel.entry_key).toBe("pools.index");
    expect(payload.web_channel.route_key).toBe("/pools");
    expect(payload.role_restrictions).toEqual({ any_of: ["authenticated"] });
  });

  it("normalizes content block payloads for the admin RPC", () => {
    const payload = buildPlatformContentBlockPayload({
      block_key: " Home Promo ",
      block_type: " Promo_Banner ",
      title: "Derby Day",
      content: { cta_route: "/pools" },
      target_channel: "both",
      is_active: true,
      sort_order: 12,
      feature_key: " pools ",
      placement_key: " Home.Primary ",
      metadata: { dismissible: true },
    });

    expect(payload.block_key).toBe("home promo");
    expect(payload.block_type).toBe("promo_banner");
    expect(payload.feature_key).toBe("pools");
    expect(payload.placement_key).toBe("home.primary");
    expect(payload.metadata).toEqual({ dismissible: true });
  });
});
