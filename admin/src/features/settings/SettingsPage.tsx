import { useState, type FormEvent, type ReactNode } from "react";
import { PageHeader } from "../../components/layout/PageHeader";
import { KpiCard } from "../../components/ui/KpiCard";
import {
  EmptyState,
  ErrorState,
  LoadingState,
} from "../../components/ui/StateViews";
import {
  useCountryCurrencyEntries,
  useCountryRegionEntries,
  useCurrencyDisplayMetadata,
  useDeleteCountryCurrencyEntry,
  useDeleteCountryRegionEntry,
  useDeleteCurrencyDisplayMetadata,
  useDeleteLaunchMoment,
  useDeletePhonePreset,
  useDeleteRuntimeConfigEntry,
  useFeatureFlags,
  useLaunchMoments,
  usePhonePresets,
  useRuntimeConfigEntries,
  useToggleFeatureFlag,
  useUpsertCountryCurrencyEntry,
  useUpsertCountryRegionEntry,
  useUpsertCurrencyDisplayMetadata,
  useUpsertFeatureFlag,
  useUpsertLaunchMoment,
  useUpsertPhonePreset,
  useUpsertRuntimeConfigEntry,
} from "./useSettings";
import { formatDateTime } from "../../lib/formatters";
import {
  Database,
  Globe,
  Pencil,
  Plus,
  Search,
  Shield,
  ToggleLeft,
  ToggleRight,
  Trash2,
  Zap,
} from "lucide-react";
import type {
  CountryCurrencyEntry,
  CountryRegionEntry,
  CurrencyDisplayMetadata,
  FeatureFlag,
  LaunchMoment,
  PhonePreset,
  RuntimeConfigEntry,
} from "../../types";

type FeaturePlatform = "all" | "android" | "ios" | "web";

const emptyFlagForm = {
  key: "",
  market: "global",
  platform: "all" as FeaturePlatform,
  description: "",
  enabled: false,
};

const emptyRuntimeConfigForm = {
  key: "",
  valueText: '"value"',
};

const emptyLaunchMomentForm = {
  tag: "",
  title: "",
  subtitle: "",
  kicker: "",
  region_key: "global",
  sort_order: 0,
  is_active: true,
};

const emptyPhonePresetForm = {
  country_code: "",
  dial_code: "+",
  hint: "",
  min_digits: 7,
};

const emptyCurrencyForm = {
  currency_code: "",
  symbol: "",
  decimals: 2,
  space_separated: false,
};

const emptyCountryRegionForm = {
  country_code: "",
  region: "global",
  country_name: "",
  flag_emoji: "🌍",
};

const emptyCountryCurrencyForm = {
  country_code: "",
  currency_code: "",
  country_name: "",
};

const launchRegions = ["global", "africa", "europe", "north_america"];
const runtimeRegions = [
  "global",
  "africa",
  "europe",
  "americas",
  "north_america",
];

function platformForFlag(flag: FeatureFlag): string {
  const platform = flag.config?.platform;
  return typeof platform === "string" && platform.length > 0 ? platform : "all";
}

function rolloutForFlag(flag: FeatureFlag): number {
  const rollout = flag.config?.rollout_pct;
  return typeof rollout === "number" ? rollout : 100;
}

function formatJsonValue(value: unknown) {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

function jsonPreview(value: unknown) {
  const text = formatJsonValue(value).replace(/\s+/g, " ").trim();
  return text.length > 84 ? `${text.slice(0, 84)}…` : text;
}

function SectionCard({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <div className="card mt-6">
      <div className="mb-4">
        <h3 className="text-md font-semibold">{title}</h3>
        <p className="text-sm text-muted mt-1">{description}</p>
      </div>
      {children}
    </div>
  );
}

export function SettingsPage() {
  const [search, setSearch] = useState("");
  const [marketFilter, setMarketFilter] = useState("all");
  const [moduleFilter, setModuleFilter] = useState("all");
  const [platformFilter, setPlatformFilter] = useState("all");
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [newFlag, setNewFlag] = useState(emptyFlagForm);

  const [runtimeConfigForm, setRuntimeConfigForm] = useState(
    emptyRuntimeConfigForm,
  );
  const [runtimeConfigEditingKey, setRuntimeConfigEditingKey] = useState<
    string | null
  >(null);
  const [runtimeConfigError, setRuntimeConfigError] = useState<string | null>(
    null,
  );

  const [launchMomentForm, setLaunchMomentForm] = useState(
    emptyLaunchMomentForm,
  );
  const [launchMomentEditingTag, setLaunchMomentEditingTag] = useState<
    string | null
  >(null);

  const [phonePresetForm, setPhonePresetForm] = useState(emptyPhonePresetForm);
  const [phonePresetEditingCode, setPhonePresetEditingCode] = useState<
    string | null
  >(null);

  const [currencyForm, setCurrencyForm] = useState(emptyCurrencyForm);
  const [currencyEditingCode, setCurrencyEditingCode] = useState<string | null>(
    null,
  );
  const [countryRegionForm, setCountryRegionForm] = useState(
    emptyCountryRegionForm,
  );
  const [countryRegionEditingCode, setCountryRegionEditingCode] = useState<
    string | null
  >(null);
  const [countryCurrencyForm, setCountryCurrencyForm] = useState(
    emptyCountryCurrencyForm,
  );
  const [countryCurrencyEditingCode, setCountryCurrencyEditingCode] = useState<
    string | null
  >(null);

  const { data: flags = [], isLoading, error, refetch } = useFeatureFlags();
  const { data: runtimeConfig = [] } = useRuntimeConfigEntries();
  const { data: launchMoments = [] } = useLaunchMoments();
  const { data: phonePresets = [] } = usePhonePresets();
  const { data: currencyDisplay = [] } = useCurrencyDisplayMetadata();
  const { data: countryRegionEntries = [] } = useCountryRegionEntries();
  const { data: countryCurrencyEntries = [] } = useCountryCurrencyEntries();

  const toggleMutation = useToggleFeatureFlag();
  const upsertFlagMutation = useUpsertFeatureFlag();
  const upsertRuntimeConfigMutation = useUpsertRuntimeConfigEntry();
  const deleteRuntimeConfigMutation = useDeleteRuntimeConfigEntry();
  const upsertLaunchMomentMutation = useUpsertLaunchMoment();
  const deleteLaunchMomentMutation = useDeleteLaunchMoment();
  const upsertPhonePresetMutation = useUpsertPhonePreset();
  const deletePhonePresetMutation = useDeletePhonePreset();
  const upsertCurrencyMutation = useUpsertCurrencyDisplayMetadata();
  const deleteCurrencyMutation = useDeleteCurrencyDisplayMetadata();
  const upsertCountryRegionMutation = useUpsertCountryRegionEntry();
  const deleteCountryRegionMutation = useDeleteCountryRegionEntry();
  const upsertCountryCurrencyMutation = useUpsertCountryCurrencyEntry();
  const deleteCountryCurrencyMutation = useDeleteCountryCurrencyEntry();

  const enabledCount = flags.filter((flag) => flag.is_enabled).length;
  const disabledCount = flags.length - enabledCount;
  const markets = [...new Set(flags.map((flag) => flag.market))].sort();
  const modules = [
    ...new Set(flags.map((flag) => flag.module?.trim() || "uncategorized")),
  ].sort();
  const platforms = [...new Set(flags.map(platformForFlag))].sort();

  const normalizedSearch = search.trim().toLowerCase();
  const filteredFlags = flags.filter((flag) => {
    const platform = platformForFlag(flag);
    const module = flag.module?.trim() || "uncategorized";
    const matchesSearch =
      normalizedSearch.length === 0 ||
      [
        flag.key,
        flag.label,
        flag.description ?? "",
        flag.market,
        module,
        platform,
      ].some((value) => value.toLowerCase().includes(normalizedSearch));

    const matchesMarket =
      marketFilter === "all" || flag.market === marketFilter;
    const matchesModule = moduleFilter === "all" || module === moduleFilter;
    const matchesPlatform =
      platformFilter === "all" || platform === platformFilter;

    return matchesSearch && matchesMarket && matchesModule && matchesPlatform;
  });

  const marketCards = markets.map((market) => {
    const scoped = flags.filter((flag) => flag.market === market);
    return {
      market,
      total: scoped.length,
      enabled: scoped.filter((flag) => flag.is_enabled).length,
    };
  });

  const handleToggle = async (flag: FeatureFlag) => {
    await toggleMutation.mutateAsync({
      p_flag_id: flag.id,
      p_is_enabled: !flag.is_enabled,
    });
  };

  const handleCreateFlag = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    await upsertFlagMutation.mutateAsync({
      key: newFlag.key,
      market: newFlag.market,
      platform: newFlag.platform,
      enabled: newFlag.enabled,
      description: newFlag.description,
    });
    setNewFlag(emptyFlagForm);
    setShowCreateForm(false);
  };

  const handleRuntimeConfigSubmit = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();
    setRuntimeConfigError(null);

    try {
      const parsed = JSON.parse(runtimeConfigForm.valueText);
      await upsertRuntimeConfigMutation.mutateAsync({
        key: runtimeConfigForm.key,
        value: parsed,
      });
      setRuntimeConfigForm(emptyRuntimeConfigForm);
      setRuntimeConfigEditingKey(null);
    } catch (submissionError) {
      setRuntimeConfigError(
        submissionError instanceof Error
          ? submissionError.message
          : "Runtime config value must be valid JSON.",
      );
    }
  };

  const editRuntimeConfig = (entry: RuntimeConfigEntry) => {
    setRuntimeConfigEditingKey(entry.key);
    setRuntimeConfigForm({
      key: entry.key,
      valueText: formatJsonValue(entry.value),
    });
    setRuntimeConfigError(null);
  };

  const deleteRuntimeConfig = async (key: string) => {
    if (!window.confirm(`Delete runtime config '${key}'?`)) return;
    await deleteRuntimeConfigMutation.mutateAsync({ key });
    if (runtimeConfigEditingKey === key) {
      setRuntimeConfigForm(emptyRuntimeConfigForm);
      setRuntimeConfigEditingKey(null);
    }
  };

  const handleLaunchMomentSubmit = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();
    await upsertLaunchMomentMutation.mutateAsync({
      ...launchMomentForm,
      sort_order: Number(launchMomentForm.sort_order),
    });
    setLaunchMomentForm(emptyLaunchMomentForm);
    setLaunchMomentEditingTag(null);
  };

  const editLaunchMoment = (moment: LaunchMoment) => {
    setLaunchMomentEditingTag(moment.tag);
    setLaunchMomentForm({
      tag: moment.tag,
      title: moment.title,
      subtitle: moment.subtitle,
      kicker: moment.kicker,
      region_key: moment.region_key,
      sort_order: moment.sort_order,
      is_active: moment.is_active,
    });
  };

  const deleteLaunchMoment = async (tag: string) => {
    if (!window.confirm(`Delete launch moment '${tag}'?`)) return;
    await deleteLaunchMomentMutation.mutateAsync({ tag });
    if (launchMomentEditingTag === tag) {
      setLaunchMomentForm(emptyLaunchMomentForm);
      setLaunchMomentEditingTag(null);
    }
  };

  const handlePhonePresetSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    await upsertPhonePresetMutation.mutateAsync({
      ...phonePresetForm,
      min_digits: Number(phonePresetForm.min_digits),
    });
    setPhonePresetForm(emptyPhonePresetForm);
    setPhonePresetEditingCode(null);
  };

  const editPhonePreset = (preset: PhonePreset) => {
    setPhonePresetEditingCode(preset.country_code);
    setPhonePresetForm({
      country_code: preset.country_code,
      dial_code: preset.dial_code,
      hint: preset.hint,
      min_digits: preset.min_digits,
    });
  };

  const deletePhonePreset = async (country_code: string) => {
    if (!window.confirm(`Delete phone preset '${country_code}'?`)) return;
    await deletePhonePresetMutation.mutateAsync({ country_code });
    if (phonePresetEditingCode === country_code) {
      setPhonePresetForm(emptyPhonePresetForm);
      setPhonePresetEditingCode(null);
    }
  };

  const handleCurrencySubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    await upsertCurrencyMutation.mutateAsync({
      ...currencyForm,
      decimals: Number(currencyForm.decimals),
    });
    setCurrencyForm(emptyCurrencyForm);
    setCurrencyEditingCode(null);
  };

  const editCurrency = (currency: CurrencyDisplayMetadata) => {
    setCurrencyEditingCode(currency.currency_code);
    setCurrencyForm({
      currency_code: currency.currency_code,
      symbol: currency.symbol,
      decimals: currency.decimals,
      space_separated: currency.space_separated,
    });
  };

  const deleteCurrency = async (currency_code: string) => {
    if (!window.confirm(`Delete currency metadata '${currency_code}'?`)) {
      return;
    }
    await deleteCurrencyMutation.mutateAsync({ currency_code });
    if (currencyEditingCode === currency_code) {
      setCurrencyForm(emptyCurrencyForm);
      setCurrencyEditingCode(null);
    }
  };

  const handleCountryRegionSubmit = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();
    await upsertCountryRegionMutation.mutateAsync(countryRegionForm);
    setCountryRegionForm(emptyCountryRegionForm);
    setCountryRegionEditingCode(null);
  };

  const editCountryRegion = (entry: CountryRegionEntry) => {
    setCountryRegionEditingCode(entry.country_code);
    setCountryRegionForm({
      country_code: entry.country_code,
      region: entry.region,
      country_name: entry.country_name,
      flag_emoji: entry.flag_emoji,
    });
  };

  const deleteCountryRegion = async (country_code: string) => {
    if (!window.confirm(`Delete region mapping '${country_code}'?`)) return;
    await deleteCountryRegionMutation.mutateAsync({ country_code });
    if (countryRegionEditingCode === country_code) {
      setCountryRegionForm(emptyCountryRegionForm);
      setCountryRegionEditingCode(null);
    }
  };

  const handleCountryCurrencySubmit = async (
    event: FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();
    await upsertCountryCurrencyMutation.mutateAsync(countryCurrencyForm);
    setCountryCurrencyForm(emptyCountryCurrencyForm);
    setCountryCurrencyEditingCode(null);
  };

  const editCountryCurrency = (entry: CountryCurrencyEntry) => {
    setCountryCurrencyEditingCode(entry.country_code);
    setCountryCurrencyForm({
      country_code: entry.country_code,
      currency_code: entry.currency_code,
      country_name: entry.country_name ?? "",
    });
  };

  const deleteCountryCurrency = async (country_code: string) => {
    if (!window.confirm(`Delete currency mapping '${country_code}'?`)) return;
    await deleteCountryCurrencyMutation.mutateAsync({ country_code });
    if (countryCurrencyEditingCode === country_code) {
      setCountryCurrencyForm(emptyCountryCurrencyForm);
      setCountryCurrencyEditingCode(null);
    }
  };

  return (
    <div>
      <PageHeader
        title="Runtime Settings & Feature Flags"
        subtitle="Flutter bootstrap reads these records live from Supabase. This page manages the same runtime control plane the app consumes."
        actions={
          <button
            className="btn btn-primary"
            type="button"
            onClick={() => setShowCreateForm((value) => !value)}
          >
            <Plus size={16} /> {showCreateForm ? "Close" : "Add Flag"}
          </button>
        }
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard
          label="Total Flags"
          value={flags.length}
          icon={<Shield size={18} />}
        />
        <KpiCard
          label="Enabled"
          value={enabledCount}
          icon={<Zap size={18} />}
        />
        <KpiCard
          label="Markets"
          value={markets.length}
          icon={<Globe size={18} />}
        />
        <KpiCard
          label="Bootstrap Records"
          value={
            runtimeConfig.length +
            launchMoments.length +
            phonePresets.length +
            currencyDisplay.length +
            countryRegionEntries.length +
            countryCurrencyEntries.length
          }
          icon={<Database size={18} />}
        />
      </div>

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard
          label="App Config Keys"
          value={runtimeConfig.length}
          icon={<Database size={18} />}
        />
        <KpiCard
          label="Launch Moments"
          value={launchMoments.length}
          icon={<Globe size={18} />}
        />
        <KpiCard
          label="Phone Presets"
          value={phonePresets.length}
          icon={<Shield size={18} />}
        />
        <KpiCard
          label="Currency Display"
          value={currencyDisplay.length}
          icon={<Zap size={18} />}
        />
        <KpiCard
          label="Country Regions"
          value={countryRegionEntries.length}
          icon={<Globe size={18} />}
        />
        <KpiCard
          label="Country Currencies"
          value={countryCurrencyEntries.length}
          icon={<Database size={18} />}
        />
      </div>

      {showCreateForm && (
        <form className="card mb-6" onSubmit={handleCreateFlag}>
          <h3 className="text-md font-semibold mb-4">Create Feature Flag</h3>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Key</div>
              <input
                className="input"
                placeholder="predictions"
                value={newFlag.key}
                onChange={(event) =>
                  setNewFlag((current) => ({
                    ...current,
                    key: event.target.value
                      .trim()
                      .toLowerCase()
                      .replace(/[^a-z0-9_]+/g, "_"),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Market</div>
              <input
                className="input"
                placeholder="global"
                value={newFlag.market}
                onChange={(event) =>
                  setNewFlag((current) => ({
                    ...current,
                    market: event.target.value
                      .trim()
                      .toLowerCase()
                      .replace(/[^a-z_]+/g, "_"),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Platform</div>
              <select
                className="input select"
                value={newFlag.platform}
                onChange={(event) =>
                  setNewFlag((current) => ({
                    ...current,
                    platform: event.target.value as FeaturePlatform,
                  }))
                }
              >
                <option value="all">All</option>
                <option value="android">Android</option>
                <option value="ios">iOS</option>
                <option value="web">Web</option>
              </select>
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Description</div>
              <input
                className="input"
                placeholder="Controls prediction entry visibility"
                value={newFlag.description}
                onChange={(event) =>
                  setNewFlag((current) => ({
                    ...current,
                    description: event.target.value,
                  }))
                }
              />
            </label>
          </div>
          <label className="flex items-center gap-2 mb-4">
            <input
              type="checkbox"
              checked={newFlag.enabled}
              onChange={(event) =>
                setNewFlag((current) => ({
                  ...current,
                  enabled: event.target.checked,
                }))
              }
            />
            <span className="text-sm">Enable immediately</span>
          </label>
          <div className="flex gap-2">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertFlagMutation.isPending}
            >
              Save Flag
            </button>
            <button
              className="btn btn-secondary"
              type="button"
              onClick={() => {
                setNewFlag(emptyFlagForm);
                setShowCreateForm(false);
              }}
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      <div className="card mb-6">
        <h3 className="text-md font-semibold mb-4 flex items-center gap-2">
          <Globe size={18} className="text-primary" /> Market Distribution
        </h3>
        {marketCards.length === 0 ? (
          <EmptyState
            title="No runtime markets"
            description="Create a feature flag to start building a live runtime rollout surface."
            icon={<Globe size={48} />}
          />
        ) : (
          <div className="grid grid-2 gap-4">
            {marketCards.map((card) => (
              <div
                key={card.market}
                className="p-4"
                style={{
                  background: "var(--fz-surface-2)",
                  borderRadius: "var(--fz-radius)",
                }}
              >
                <div className="flex items-center gap-2 mb-2">
                  <span className="font-semibold">
                    {card.market.replace(/_/g, " ")}
                  </span>
                  <span className="badge badge-neutral ml-auto">
                    {card.total} flags
                  </span>
                </div>
                <p className="text-sm text-muted">
                  {card.enabled} enabled, {card.total - card.enabled} disabled
                </p>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="filter-bar mb-4">
        <div style={{ position: "relative", maxWidth: 320 }}>
          <Search
            size={16}
            style={{
              position: "absolute",
              left: 12,
              top: "50%",
              transform: "translateY(-50%)",
              color: "var(--fz-muted-2)",
            }}
          />
          <input
            className="input"
            style={{ paddingLeft: 36 }}
            placeholder="Search feature flags..."
            value={search}
            onChange={(event) => setSearch(event.target.value)}
          />
        </div>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={marketFilter}
          onChange={(event) => setMarketFilter(event.target.value)}
        >
          <option value="all">All markets</option>
          {markets.map((market) => (
            <option key={market} value={market}>
              {market}
            </option>
          ))}
        </select>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={moduleFilter}
          onChange={(event) => setModuleFilter(event.target.value)}
        >
          <option value="all">All modules</option>
          {modules.map((module) => (
            <option key={module} value={module}>
              {module}
            </option>
          ))}
        </select>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={platformFilter}
          onChange={(event) => setPlatformFilter(event.target.value)}
        >
          <option value="all">All platforms</option>
          {platforms.map((platform) => (
            <option key={platform} value={platform}>
              {platform}
            </option>
          ))}
        </select>
      </div>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : filteredFlags.length === 0 ? (
        <EmptyState
          title="No feature flags found"
          description="Adjust the filters or create a new runtime flag."
          icon={<Shield size={48} />}
        />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Feature</th>
                <th>Key</th>
                <th>Module</th>
                <th>Market</th>
                <th>Platform</th>
                <th>Rollout</th>
                <th>Updated</th>
                <th>Status</th>
                <th className="cell-actions">Toggle</th>
              </tr>
            </thead>
            <tbody>
              {filteredFlags.map((flag) => {
                const platform = platformForFlag(flag);
                return (
                  <tr key={flag.id}>
                    <td>
                      <div className="font-medium">{flag.label}</div>
                      <div className="text-xs text-muted">
                        {flag.description || "No description"}
                      </div>
                    </td>
                    <td className="mono text-xs">{flag.key}</td>
                    <td>
                      <span className="badge badge-neutral">
                        {flag.module || "uncategorized"}
                      </span>
                    </td>
                    <td>{flag.market}</td>
                    <td>{platform}</td>
                    <td>{rolloutForFlag(flag)}%</td>
                    <td className="text-xs text-muted">
                      {formatDateTime(flag.updated_at)}
                    </td>
                    <td>
                      <span
                        className={`badge ${flag.is_enabled ? "badge-success" : "badge-neutral"}`}
                      >
                        {flag.is_enabled ? "Enabled" : "Disabled"}
                      </span>
                    </td>
                    <td className="cell-actions">
                      <button
                        className="btn btn-ghost btn-icon"
                        onClick={() => handleToggle(flag)}
                        title={flag.is_enabled ? "Disable" : "Enable"}
                        disabled={toggleMutation.isPending}
                      >
                        {flag.is_enabled ? (
                          <ToggleRight size={24} className="text-success" />
                        ) : (
                          <ToggleLeft size={24} className="text-muted" />
                        )}
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <SectionCard
        title="App Config Remote"
        description="Key-value runtime settings read by Flutter through get_app_bootstrap_config. Values must be valid JSON."
      >
        <form onSubmit={handleRuntimeConfigSubmit}>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Key</div>
              <input
                className="input"
                value={runtimeConfigForm.key}
                onChange={(event) =>
                  setRuntimeConfigForm((current) => ({
                    ...current,
                    key: event.target.value.trim(),
                  }))
                }
                placeholder="default_phone_country_code"
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">JSON Value</div>
              <textarea
                className="input"
                rows={4}
                value={runtimeConfigForm.valueText}
                onChange={(event) =>
                  setRuntimeConfigForm((current) => ({
                    ...current,
                    valueText: event.target.value,
                  }))
                }
              />
            </label>
          </div>
          {runtimeConfigError && (
            <div className="text-sm text-error mb-4">{runtimeConfigError}</div>
          )}
          <div className="flex gap-2 mb-4">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertRuntimeConfigMutation.isPending}
            >
              {runtimeConfigEditingKey ? "Update Config" : "Save Config"}
            </button>
            {runtimeConfigEditingKey && (
              <button
                className="btn btn-secondary"
                type="button"
                onClick={() => {
                  setRuntimeConfigForm(emptyRuntimeConfigForm);
                  setRuntimeConfigEditingKey(null);
                  setRuntimeConfigError(null);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </form>
        {runtimeConfig.length === 0 ? (
          <EmptyState
            title="No runtime config keys"
            description="Create keys for country priority, default phone country, or other remote app behavior."
            icon={<Database size={48} />}
          />
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Key</th>
                  <th>Value</th>
                  <th>Updated</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {runtimeConfig.map((entry) => (
                  <tr key={entry.key}>
                    <td className="mono text-xs">{entry.key}</td>
                    <td className="text-xs text-muted">
                      {jsonPreview(entry.value)}
                    </td>
                    <td className="text-xs text-muted">
                      {formatDateTime(entry.updated_at)}
                    </td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => editRuntimeConfig(entry)}
                          title="Edit"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          className="btn btn-ghost btn-icon btn-sm text-error"
                          onClick={() => deleteRuntimeConfig(entry.key)}
                          title="Delete"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      <SectionCard
        title="Launch Moments"
        description="Dynamic launch messaging used by regional discovery and home-screen marketing surfaces."
      >
        <form onSubmit={handleLaunchMomentSubmit}>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Tag</div>
              <input
                className="input"
                value={launchMomentForm.tag}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    tag: event.target.value
                      .trim()
                      .toLowerCase()
                      .replace(/[^a-z0-9-]+/g, "-"),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Region</div>
              <select
                className="input select"
                value={launchMomentForm.region_key}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    region_key: event.target.value,
                  }))
                }
              >
                {launchRegions.map((region) => (
                  <option key={region} value={region}>
                    {region}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Title</div>
              <input
                className="input"
                value={launchMomentForm.title}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    title: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Kicker</div>
              <input
                className="input"
                value={launchMomentForm.kicker}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    kicker: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label style={{ gridColumn: "1 / -1" }}>
              <div className="text-xs text-muted mb-1">Subtitle</div>
              <textarea
                className="input"
                rows={3}
                value={launchMomentForm.subtitle}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    subtitle: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Sort Order</div>
              <input
                className="input"
                type="number"
                value={launchMomentForm.sort_order}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    sort_order: Number(event.target.value),
                  }))
                }
              />
            </label>
            <label className="flex items-center gap-2 mt-5">
              <input
                type="checkbox"
                checked={launchMomentForm.is_active}
                onChange={(event) =>
                  setLaunchMomentForm((current) => ({
                    ...current,
                    is_active: event.target.checked,
                  }))
                }
              />
              <span className="text-sm">Active</span>
            </label>
          </div>
          <div className="flex gap-2 mb-4">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertLaunchMomentMutation.isPending}
            >
              {launchMomentEditingTag
                ? "Update Launch Moment"
                : "Save Launch Moment"}
            </button>
            {launchMomentEditingTag && (
              <button
                className="btn btn-secondary"
                type="button"
                onClick={() => {
                  setLaunchMomentForm(emptyLaunchMomentForm);
                  setLaunchMomentEditingTag(null);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </form>
        {launchMoments.length === 0 ? (
          <EmptyState
            title="No launch moments"
            description="Create a launch moment to drive dynamic region-aware messaging."
            icon={<Globe size={48} />}
          />
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Tag</th>
                  <th>Title</th>
                  <th>Region</th>
                  <th>Sort</th>
                  <th>Status</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {launchMoments.map((moment) => (
                  <tr key={moment.tag}>
                    <td className="mono text-xs">{moment.tag}</td>
                    <td>
                      <div className="font-medium">{moment.title}</div>
                      <div className="text-xs text-muted">{moment.kicker}</div>
                    </td>
                    <td>{moment.region_key}</td>
                    <td>{moment.sort_order}</td>
                    <td>
                      <span
                        className={`badge ${moment.is_active ? "badge-success" : "badge-neutral"}`}
                      >
                        {moment.is_active ? "Active" : "Inactive"}
                      </span>
                    </td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => editLaunchMoment(moment)}
                          title="Edit"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          className="btn btn-ghost btn-icon btn-sm text-error"
                          onClick={() => deleteLaunchMoment(moment.tag)}
                          title="Delete"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      <SectionCard
        title="Phone Presets"
        description="Country dial-code, hint, and digit rules used by WhatsApp login and onboarding."
      >
        <form onSubmit={handlePhonePresetSubmit}>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Country Code</div>
              <input
                className="input"
                value={phonePresetForm.country_code}
                onChange={(event) =>
                  setPhonePresetForm((current) => ({
                    ...current,
                    country_code: event.target.value
                      .trim()
                      .toUpperCase()
                      .slice(0, 2),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Dial Code</div>
              <input
                className="input"
                value={phonePresetForm.dial_code}
                onChange={(event) =>
                  setPhonePresetForm((current) => ({
                    ...current,
                    dial_code: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Hint</div>
              <input
                className="input"
                value={phonePresetForm.hint}
                onChange={(event) =>
                  setPhonePresetForm((current) => ({
                    ...current,
                    hint: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Min Digits</div>
              <input
                className="input"
                type="number"
                value={phonePresetForm.min_digits}
                onChange={(event) =>
                  setPhonePresetForm((current) => ({
                    ...current,
                    min_digits: Number(event.target.value),
                  }))
                }
                required
              />
            </label>
          </div>
          <div className="flex gap-2 mb-4">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertPhonePresetMutation.isPending}
            >
              {phonePresetEditingCode
                ? "Update Phone Preset"
                : "Save Phone Preset"}
            </button>
            {phonePresetEditingCode && (
              <button
                className="btn btn-secondary"
                type="button"
                onClick={() => {
                  setPhonePresetForm(emptyPhonePresetForm);
                  setPhonePresetEditingCode(null);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </form>
        {phonePresets.length === 0 ? (
          <EmptyState
            title="No phone presets"
            description="Add country dial-code presets to enable runtime-driven phone formatting."
            icon={<Shield size={48} />}
          />
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Country</th>
                  <th>Dial Code</th>
                  <th>Hint</th>
                  <th>Min Digits</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {phonePresets.map((preset) => (
                  <tr key={preset.country_code}>
                    <td className="mono text-xs">{preset.country_code}</td>
                    <td>{preset.dial_code}</td>
                    <td>{preset.hint}</td>
                    <td>{preset.min_digits}</td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => editPhonePreset(preset)}
                          title="Edit"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          className="btn btn-ghost btn-icon btn-sm text-error"
                          onClick={() => deletePhonePreset(preset.country_code)}
                          title="Delete"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      <SectionCard
        title="Country Region Map"
        description="Country metadata used by runtime bootstrap for region routing, flag resolution, and phone-country presentation."
      >
        <form onSubmit={handleCountryRegionSubmit}>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Country Code</div>
              <input
                className="input"
                value={countryRegionForm.country_code}
                onChange={(event) =>
                  setCountryRegionForm((current) => ({
                    ...current,
                    country_code: event.target.value
                      .trim()
                      .toUpperCase()
                      .slice(0, 2),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Country Name</div>
              <input
                className="input"
                value={countryRegionForm.country_name}
                onChange={(event) =>
                  setCountryRegionForm((current) => ({
                    ...current,
                    country_name: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Region</div>
              <select
                className="input select"
                value={countryRegionForm.region}
                onChange={(event) =>
                  setCountryRegionForm((current) => ({
                    ...current,
                    region: event.target.value,
                  }))
                }
              >
                {runtimeRegions.map((region) => (
                  <option key={region} value={region}>
                    {region}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Flag Emoji</div>
              <input
                className="input"
                value={countryRegionForm.flag_emoji}
                onChange={(event) =>
                  setCountryRegionForm((current) => ({
                    ...current,
                    flag_emoji: event.target.value,
                  }))
                }
                required
              />
            </label>
          </div>
          <div className="flex gap-2 mb-4">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertCountryRegionMutation.isPending}
            >
              {countryRegionEditingCode
                ? "Update Region Mapping"
                : "Save Region Mapping"}
            </button>
            {countryRegionEditingCode && (
              <button
                className="btn btn-secondary"
                type="button"
                onClick={() => {
                  setCountryRegionForm(emptyCountryRegionForm);
                  setCountryRegionEditingCode(null);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </form>
        {countryRegionEntries.length === 0 ? (
          <EmptyState
            title="No country region mappings"
            description="Add region metadata to drive launch-market and phone-country behavior from Supabase."
            icon={<Globe size={48} />}
          />
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Country</th>
                  <th>Code</th>
                  <th>Region</th>
                  <th>Flag</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {countryRegionEntries.map((entry) => (
                  <tr key={entry.country_code}>
                    <td>{entry.country_name}</td>
                    <td className="mono text-xs">{entry.country_code}</td>
                    <td>{entry.region}</td>
                    <td>{entry.flag_emoji}</td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => editCountryRegion(entry)}
                          title="Edit"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          className="btn btn-ghost btn-icon btn-sm text-error"
                          onClick={() =>
                            deleteCountryRegion(entry.country_code)
                          }
                          title="Delete"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      <SectionCard
        title="Country Currency Map"
        description="Country-to-currency mappings used by wallet display and bootstrap locale resolution."
      >
        <form onSubmit={handleCountryCurrencySubmit}>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Country Code</div>
              <input
                className="input"
                value={countryCurrencyForm.country_code}
                onChange={(event) =>
                  setCountryCurrencyForm((current) => ({
                    ...current,
                    country_code: event.target.value
                      .trim()
                      .toUpperCase()
                      .slice(0, 2),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Currency Code</div>
              <input
                className="input"
                value={countryCurrencyForm.currency_code}
                onChange={(event) =>
                  setCountryCurrencyForm((current) => ({
                    ...current,
                    currency_code: event.target.value
                      .trim()
                      .toUpperCase()
                      .slice(0, 3),
                  }))
                }
                required
              />
            </label>
            <label style={{ gridColumn: "1 / -1" }}>
              <div className="text-xs text-muted mb-1">Country Name</div>
              <input
                className="input"
                value={countryCurrencyForm.country_name}
                onChange={(event) =>
                  setCountryCurrencyForm((current) => ({
                    ...current,
                    country_name: event.target.value,
                  }))
                }
                placeholder="Optional display label"
              />
            </label>
          </div>
          <div className="flex gap-2 mb-4">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertCountryCurrencyMutation.isPending}
            >
              {countryCurrencyEditingCode
                ? "Update Currency Mapping"
                : "Save Currency Mapping"}
            </button>
            {countryCurrencyEditingCode && (
              <button
                className="btn btn-secondary"
                type="button"
                onClick={() => {
                  setCountryCurrencyForm(emptyCountryCurrencyForm);
                  setCountryCurrencyEditingCode(null);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </form>
        {countryCurrencyEntries.length === 0 ? (
          <EmptyState
            title="No country currency mappings"
            description="Add country-to-currency rows so locale-aware reward and wallet formatting stays data-driven."
            icon={<Database size={48} />}
          />
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Country</th>
                  <th>Code</th>
                  <th>Currency</th>
                  <th>Updated</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {countryCurrencyEntries.map((entry) => (
                  <tr key={entry.country_code}>
                    <td>{entry.country_name || "—"}</td>
                    <td className="mono text-xs">{entry.country_code}</td>
                    <td className="mono text-xs">{entry.currency_code}</td>
                    <td className="text-xs text-muted">
                      {formatDateTime(entry.updated_at)}
                    </td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => editCountryCurrency(entry)}
                          title="Edit"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          className="btn btn-ghost btn-icon btn-sm text-error"
                          onClick={() =>
                            deleteCountryCurrency(entry.country_code)
                          }
                          title="Delete"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      <SectionCard
        title="Currency Display Metadata"
        description="Symbol and formatting metadata used by wallet and reward surfaces."
      >
        <form onSubmit={handleCurrencySubmit}>
          <div className="grid grid-2 gap-4 mb-4">
            <label>
              <div className="text-xs text-muted mb-1">Currency Code</div>
              <input
                className="input"
                value={currencyForm.currency_code}
                onChange={(event) =>
                  setCurrencyForm((current) => ({
                    ...current,
                    currency_code: event.target.value
                      .trim()
                      .toUpperCase()
                      .slice(0, 3),
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Symbol</div>
              <input
                className="input"
                value={currencyForm.symbol}
                onChange={(event) =>
                  setCurrencyForm((current) => ({
                    ...current,
                    symbol: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <div className="text-xs text-muted mb-1">Decimals</div>
              <input
                className="input"
                type="number"
                min={0}
                max={4}
                value={currencyForm.decimals}
                onChange={(event) =>
                  setCurrencyForm((current) => ({
                    ...current,
                    decimals: Number(event.target.value),
                  }))
                }
                required
              />
            </label>
            <label className="flex items-center gap-2 mt-5">
              <input
                type="checkbox"
                checked={currencyForm.space_separated}
                onChange={(event) =>
                  setCurrencyForm((current) => ({
                    ...current,
                    space_separated: event.target.checked,
                  }))
                }
              />
              <span className="text-sm">
                Use space between symbol and amount
              </span>
            </label>
          </div>
          <div className="flex gap-2 mb-4">
            <button
              className="btn btn-primary"
              type="submit"
              disabled={upsertCurrencyMutation.isPending}
            >
              {currencyEditingCode ? "Update Currency" : "Save Currency"}
            </button>
            {currencyEditingCode && (
              <button
                className="btn btn-secondary"
                type="button"
                onClick={() => {
                  setCurrencyForm(emptyCurrencyForm);
                  setCurrencyEditingCode(null);
                }}
              >
                Cancel
              </button>
            )}
          </div>
        </form>
        {currencyDisplay.length === 0 ? (
          <EmptyState
            title="No currency display metadata"
            description="Add formatting metadata so wallet and rewards remain DB-driven."
            icon={<Zap size={48} />}
          />
        ) : (
          <div className="data-table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Currency</th>
                  <th>Symbol</th>
                  <th>Decimals</th>
                  <th>Spacing</th>
                  <th className="cell-actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {currencyDisplay.map((currency) => (
                  <tr key={currency.currency_code}>
                    <td className="mono text-xs">{currency.currency_code}</td>
                    <td>{currency.symbol}</td>
                    <td>{currency.decimals}</td>
                    <td>{currency.space_separated ? "spaced" : "tight"}</td>
                    <td className="cell-actions">
                      <div className="flex gap-1">
                        <button
                          className="btn btn-ghost btn-icon btn-sm"
                          onClick={() => editCurrency(currency)}
                          title="Edit"
                        >
                          <Pencil size={14} />
                        </button>
                        <button
                          className="btn btn-ghost btn-icon btn-sm text-error"
                          onClick={() => deleteCurrency(currency.currency_code)}
                          title="Delete"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </SectionCard>

      <div className="text-xs text-muted mt-4">
        {disabledCount} disabled flags remain in the runtime catalog.
      </div>
    </div>
  );
}
