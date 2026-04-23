// FANZONE Admin — Settings (Feature Flags) Data Hooks
import {
  useRpcMutation,
  useSupabaseList,
  useSupabaseMutation,
} from "../../hooks/useSupabaseQuery";
import {
  adminEnvError,
  isSupabaseConfigured,
  supabase,
} from "../../lib/supabase";
import type {
  CountryCurrencyEntry,
  CountryRegionEntry,
  CurrencyDisplayMetadata,
  FeatureFlag,
  LaunchMoment,
  PhonePreset,
  RuntimeConfigEntry,
} from "../../types";

/* ── Hooks ── */
export function useFeatureFlags() {
  return useSupabaseList<FeatureFlag>(
    ["feature-flags"],
    "admin_feature_flags",
    {
      order: { column: "module", ascending: true },
    },
  );
}

export function useToggleFeatureFlag() {
  return useRpcMutation<{ p_flag_id: string; p_is_enabled: boolean }>({
    fnName: "admin_set_feature_flag",
    invalidateKeys: [["feature-flags"]],
    successMessage: "Feature flag updated.",
  });
}

export interface UpsertFeatureFlagArgs {
  key: string;
  market: string;
  platform: "all" | "android" | "ios" | "web";
  enabled: boolean;
  description?: string;
  rollout_pct?: number;
}

export function useUpsertFeatureFlag() {
  return useSupabaseMutation<UpsertFeatureFlagArgs>({
    mutationFn: async ({
      key,
      market,
      platform,
      enabled,
      description,
      rollout_pct,
    }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        key: key.trim(),
        market: market.trim().toLowerCase(),
        platform,
        enabled,
        description: description?.trim() ? description.trim() : null,
        rollout_pct: rollout_pct ?? 100,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("feature_flags")
        .upsert(payload, { onConflict: "key,market,platform" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["feature-flags"]],
    successMessage: "Feature flag saved.",
  });
}

export function useRuntimeConfigEntries() {
  return useSupabaseList<RuntimeConfigEntry>(
    ["runtime-config-entries"],
    "app_config_remote",
    { order: { column: "key", ascending: true } },
  );
}

export interface UpsertRuntimeConfigEntryArgs {
  key: string;
  value: unknown;
}

export function useUpsertRuntimeConfigEntry() {
  return useSupabaseMutation<UpsertRuntimeConfigEntryArgs>({
    mutationFn: async ({ key, value }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        key: key.trim(),
        value,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("app_config_remote")
        .upsert(payload, { onConflict: "key" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["runtime-config-entries"]],
    successMessage: "Runtime config saved.",
  });
}

export function useDeleteRuntimeConfigEntry() {
  return useSupabaseMutation<{ key: string }>({
    mutationFn: async ({ key }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { error } = await supabase
        .from("app_config_remote")
        .delete()
        .eq("key", key);

      if (error) {
        throw new Error(error.message);
      }
    },
    invalidateKeys: [["runtime-config-entries"]],
    successMessage: "Runtime config deleted.",
  });
}

export function useLaunchMoments() {
  return useSupabaseList<LaunchMoment>(["launch-moments"], "launch_moments", {
    order: { column: "sort_order", ascending: true },
  });
}

export interface UpsertLaunchMomentArgs {
  tag: string;
  title: string;
  subtitle: string;
  kicker: string;
  region_key: string;
  sort_order: number;
  is_active: boolean;
}

export function useUpsertLaunchMoment() {
  return useSupabaseMutation<UpsertLaunchMomentArgs>({
    mutationFn: async (args) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        ...args,
        tag: args.tag.trim(),
        title: args.title.trim(),
        subtitle: args.subtitle.trim(),
        kicker: args.kicker.trim(),
        region_key: args.region_key.trim().toLowerCase(),
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("launch_moments")
        .upsert(payload, { onConflict: "tag" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["launch-moments"]],
    successMessage: "Launch moment saved.",
  });
}

export function useDeleteLaunchMoment() {
  return useSupabaseMutation<{ tag: string }>({
    mutationFn: async ({ tag }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { error } = await supabase
        .from("launch_moments")
        .delete()
        .eq("tag", tag);

      if (error) {
        throw new Error(error.message);
      }
    },
    invalidateKeys: [["launch-moments"]],
    successMessage: "Launch moment deleted.",
  });
}

export function usePhonePresets() {
  return useSupabaseList<PhonePreset>(["phone-presets"], "phone_presets", {
    order: { column: "country_code", ascending: true },
  });
}

export interface UpsertPhonePresetArgs {
  country_code: string;
  dial_code: string;
  hint: string;
  min_digits: number;
}

export function useUpsertPhonePreset() {
  return useSupabaseMutation<UpsertPhonePresetArgs>({
    mutationFn: async (args) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        country_code: args.country_code.trim().toUpperCase(),
        dial_code: args.dial_code.trim(),
        hint: args.hint.trim(),
        min_digits: args.min_digits,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("phone_presets")
        .upsert(payload, { onConflict: "country_code" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["phone-presets"]],
    successMessage: "Phone preset saved.",
  });
}

export function useDeletePhonePreset() {
  return useSupabaseMutation<{ country_code: string }>({
    mutationFn: async ({ country_code }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { error } = await supabase
        .from("phone_presets")
        .delete()
        .eq("country_code", country_code);

      if (error) {
        throw new Error(error.message);
      }
    },
    invalidateKeys: [["phone-presets"]],
    successMessage: "Phone preset deleted.",
  });
}

export function useCurrencyDisplayMetadata() {
  return useSupabaseList<CurrencyDisplayMetadata>(
    ["currency-display-metadata"],
    "currency_display_metadata",
    {
      order: { column: "currency_code", ascending: true },
    },
  );
}

export function useCountryRegionEntries() {
  return useSupabaseList<CountryRegionEntry>(
    ["country-region-entries"],
    "country_region_map",
    {
      order: { column: "country_name", ascending: true },
    },
  );
}

export interface UpsertCountryRegionEntryArgs {
  country_code: string;
  region: string;
  country_name: string;
  flag_emoji: string;
}

export function useUpsertCountryRegionEntry() {
  return useSupabaseMutation<UpsertCountryRegionEntryArgs>({
    mutationFn: async (args) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        country_code: args.country_code.trim().toUpperCase(),
        region: args.region.trim().toLowerCase(),
        country_name: args.country_name.trim(),
        flag_emoji: args.flag_emoji.trim() || "🌍",
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("country_region_map")
        .upsert(payload, { onConflict: "country_code" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["country-region-entries"]],
    successMessage: "Country region mapping saved.",
  });
}

export function useDeleteCountryRegionEntry() {
  return useSupabaseMutation<{ country_code: string }>({
    mutationFn: async ({ country_code }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { error } = await supabase
        .from("country_region_map")
        .delete()
        .eq("country_code", country_code);

      if (error) {
        throw new Error(error.message);
      }
    },
    invalidateKeys: [["country-region-entries"]],
    successMessage: "Country region mapping deleted.",
  });
}

export function useCountryCurrencyEntries() {
  return useSupabaseList<CountryCurrencyEntry>(
    ["country-currency-entries"],
    "country_currency_map",
    {
      order: { column: "country_name", ascending: true },
    },
  );
}

export interface UpsertCountryCurrencyEntryArgs {
  country_code: string;
  currency_code: string;
  country_name: string;
}

export function useUpsertCountryCurrencyEntry() {
  return useSupabaseMutation<UpsertCountryCurrencyEntryArgs>({
    mutationFn: async (args) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        country_code: args.country_code.trim().toUpperCase(),
        currency_code: args.currency_code.trim().toUpperCase(),
        country_name: args.country_name.trim() || null,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("country_currency_map")
        .upsert(payload, { onConflict: "country_code" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["country-currency-entries"]],
    successMessage: "Country currency mapping saved.",
  });
}

export function useDeleteCountryCurrencyEntry() {
  return useSupabaseMutation<{ country_code: string }>({
    mutationFn: async ({ country_code }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { error } = await supabase
        .from("country_currency_map")
        .delete()
        .eq("country_code", country_code);

      if (error) {
        throw new Error(error.message);
      }
    },
    invalidateKeys: [["country-currency-entries"]],
    successMessage: "Country currency mapping deleted.",
  });
}

export interface UpsertCurrencyDisplayMetadataArgs {
  currency_code: string;
  symbol: string;
  decimals: number;
  space_separated: boolean;
}

export function useUpsertCurrencyDisplayMetadata() {
  return useSupabaseMutation<UpsertCurrencyDisplayMetadataArgs>({
    mutationFn: async (args) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const payload = {
        currency_code: args.currency_code.trim().toUpperCase(),
        symbol: args.symbol,
        decimals: args.decimals,
        space_separated: args.space_separated,
        updated_at: new Date().toISOString(),
      };

      const { data, error } = await supabase
        .from("currency_display_metadata")
        .upsert(payload, { onConflict: "currency_code" })
        .select()
        .single();

      if (error) {
        throw new Error(error.message);
      }

      return data;
    },
    invalidateKeys: [["currency-display-metadata"]],
    successMessage: "Currency display metadata saved.",
  });
}

export function useDeleteCurrencyDisplayMetadata() {
  return useSupabaseMutation<{ currency_code: string }>({
    mutationFn: async ({ currency_code }) => {
      if (!isSupabaseConfigured) {
        throw new Error(adminEnvError);
      }

      const { error } = await supabase
        .from("currency_display_metadata")
        .delete()
        .eq("currency_code", currency_code);

      if (error) {
        throw new Error(error.message);
      }
    },
    invalidateKeys: [["currency-display-metadata"]],
    successMessage: "Currency display metadata deleted.",
  });
}
