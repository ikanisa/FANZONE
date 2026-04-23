import {
  useEffect,
  useMemo,
  useState,
  type FormEvent,
  type ReactNode,
} from "react";
import {
  Globe,
  History,
  Home,
  Layers3,
  MonitorSmartphone,
  Navigation,
  Plus,
  Save,
  Search,
  Settings2,
} from "lucide-react";
import { PageHeader } from "../../components/layout/PageHeader";
import { KpiCard } from "../../components/ui/KpiCard";
import {
  EmptyState,
  ErrorState,
  LoadingState,
} from "../../components/ui/StateViews";
import { formatDateTime } from "../../lib/formatters";
import type {
  AuditLog,
  PlatformContentBlockRecord,
  PlatformFeatureChannelConfig,
  PlatformFeatureRecord,
} from "../../types";
import {
  usePlatformContentBlocks,
  usePlatformFeatureAuditLogs,
  usePlatformFeatures,
  useUpsertPlatformContentBlock,
  useUpsertPlatformFeature,
  type PlatformFeatureChannelInput,
} from "./usePlatformControl";

type FeatureStatus = "active" | "inactive" | "hidden" | "beta" | "scheduled";

interface FeatureFormState {
  feature_key: string;
  display_name: string;
  description: string;
  status: FeatureStatus;
  is_enabled: boolean;
  navigation_group: string;
  default_route_key: string;
  admin_notes: string;
  auth_required: boolean;
  dependency_config_text: string;
  rollout_config_text: string;
  schedule_start_at: string;
  schedule_end_at: string;
  mobile_channel: PlatformFeatureChannelInput;
  web_channel: PlatformFeatureChannelInput;
}

interface ContentBlockFormState {
  block_key: string;
  block_type: string;
  title: string;
  content_text: string;
  target_channel: "mobile" | "web" | "both";
  is_active: boolean;
  sort_order: number;
  feature_key: string;
  placement_key: string;
}

const emptyFeatureChannel = (
  channel: "mobile" | "web",
): PlatformFeatureChannelInput => ({
  channel,
  is_visible: true,
  is_enabled: true,
  show_in_navigation: false,
  show_on_home: false,
  sort_order: 100,
  route_key: "",
  entry_key: "",
  navigation_label: "",
  placement_key: "",
  metadata: {},
});

const emptyFeatureForm = (): FeatureFormState => ({
  feature_key: "",
  display_name: "",
  description: "",
  status: "active",
  is_enabled: true,
  navigation_group: "primary",
  default_route_key: "",
  admin_notes: "",
  auth_required: false,
  dependency_config_text: "{}",
  rollout_config_text: "{}",
  schedule_start_at: "",
  schedule_end_at: "",
  mobile_channel: emptyFeatureChannel("mobile"),
  web_channel: emptyFeatureChannel("web"),
});

const emptyContentBlockForm = (): ContentBlockFormState => ({
  block_key: "",
  block_type: "promo_banner",
  title: "",
  content_text: "{}",
  target_channel: "both",
  is_active: true,
  sort_order: 100,
  feature_key: "",
  placement_key: "home.primary",
});

function toJsonText(value: unknown) {
  try {
    return JSON.stringify(value ?? {}, null, 2);
  } catch {
    return "{}";
  }
}

function fromFeatureRecord(feature: PlatformFeatureRecord): FeatureFormState {
  return {
    feature_key: feature.feature_key,
    display_name: feature.display_name,
    description: feature.description ?? "",
    status: (feature.status as FeatureStatus) ?? "active",
    is_enabled: feature.is_enabled,
    navigation_group: feature.navigation_group ?? "",
    default_route_key: feature.default_route_key ?? "",
    admin_notes: feature.admin_notes ?? "",
    auth_required: feature.auth_required,
    dependency_config_text: toJsonText(feature.dependency_config),
    rollout_config_text: toJsonText(feature.rollout_config),
    schedule_start_at: toDateTimeInputValue(feature.schedule_start_at),
    schedule_end_at: toDateTimeInputValue(feature.schedule_end_at),
    mobile_channel: {
      ...feature.mobile_channel,
      channel: "mobile",
      route_key: feature.mobile_channel.route_key ?? "",
      entry_key: feature.mobile_channel.entry_key ?? "",
      navigation_label: feature.mobile_channel.navigation_label ?? "",
      placement_key: feature.mobile_channel.placement_key ?? "",
    },
    web_channel: {
      ...feature.web_channel,
      channel: "web",
      route_key: feature.web_channel.route_key ?? "",
      entry_key: feature.web_channel.entry_key ?? "",
      navigation_label: feature.web_channel.navigation_label ?? "",
      placement_key: feature.web_channel.placement_key ?? "",
    },
  };
}

function fromContentBlockRecord(
  block: PlatformContentBlockRecord,
): ContentBlockFormState {
  return {
    block_key: block.block_key,
    block_type: block.block_type,
    title: block.title,
    content_text: toJsonText(block.content),
    target_channel: block.target_channel,
    is_active: block.is_active,
    sort_order: block.sort_order,
    feature_key: block.feature_key ?? "",
    placement_key: block.placement_key,
  };
}

function toDateTimeInputValue(value: string | null) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 16);
}

function fromDateTimeInputValue(value: string) {
  return value.trim() ? new Date(value).toISOString() : null;
}

function parseJsonObject(value: string, label: string) {
  try {
    const parsed = JSON.parse(value || "{}");
    if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") {
      throw new Error(`${label} must be a JSON object.`);
    }
    return parsed as Record<string, unknown>;
  } catch (error) {
    const message =
      error instanceof Error ? error.message : `Invalid ${label} JSON.`;
    throw new Error(message);
  }
}

function StatusChip({ status }: { status: string }) {
  const tone =
    status === "active"
      ? "success"
      : status === "beta"
        ? "warning"
        : status === "hidden"
          ? "muted"
          : "danger";

  return <span className={`badge badge-${tone}`}>{status}</span>;
}

function ChannelPill({
  label,
  channel,
}: {
  label: string;
  channel: PlatformFeatureChannelConfig;
}) {
  return (
    <div className="flex items-center gap-2 text-xs">
      <span className="font-semibold text-text">{label}</span>
      <span className={`badge ${channel.is_enabled ? "badge-success" : "badge-danger"}`}>
        {channel.is_enabled ? "Enabled" : "Disabled"}
      </span>
      <span className={`badge ${channel.is_visible ? "badge-info" : "badge-muted"}`}>
        {channel.is_visible ? "Visible" : "Hidden"}
      </span>
      {channel.show_in_navigation && <span className="badge badge-muted">Nav</span>}
      {channel.show_on_home && <span className="badge badge-muted">Home</span>}
    </div>
  );
}

function FeatureChannelEditor({
  label,
  icon,
  channel,
  onChange,
}: {
  label: string;
  icon: ReactNode;
  channel: PlatformFeatureChannelInput;
  onChange: (next: PlatformFeatureChannelInput) => void;
}) {
  return (
    <div className="card">
      <div className="flex items-center gap-2 mb-4">
        {icon}
        <h3 className="font-semibold">{label}</h3>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={channel.is_enabled}
            onChange={(event) =>
              onChange({ ...channel, is_enabled: event.target.checked })
            }
          />
          Enabled
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={channel.is_visible}
            onChange={(event) =>
              onChange({ ...channel, is_visible: event.target.checked })
            }
          />
          Visible
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={channel.show_in_navigation}
            onChange={(event) =>
              onChange({
                ...channel,
                show_in_navigation: event.target.checked,
              })
            }
          />
          Show in navigation
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={channel.show_on_home}
            onChange={(event) =>
              onChange({ ...channel, show_on_home: event.target.checked })
            }
          />
          Show on home
        </label>
        <label className="form-field">
          <span>Sort order</span>
          <input
            className="input"
            type="number"
            value={channel.sort_order}
            onChange={(event) =>
              onChange({
                ...channel,
                sort_order: Number(event.target.value || "0"),
              })
            }
          />
        </label>
        <label className="form-field">
          <span>Route key</span>
          <input
            className="input"
            value={channel.route_key ?? ""}
            onChange={(event) =>
              onChange({ ...channel, route_key: event.target.value })
            }
          />
        </label>
        <label className="form-field">
          <span>Entry key</span>
          <input
            className="input"
            value={channel.entry_key ?? ""}
            onChange={(event) =>
              onChange({ ...channel, entry_key: event.target.value })
            }
          />
        </label>
        <label className="form-field">
          <span>Navigation label</span>
          <input
            className="input"
            value={channel.navigation_label ?? ""}
            onChange={(event) =>
              onChange({ ...channel, navigation_label: event.target.value })
            }
          />
        </label>
        <label className="form-field md:col-span-2">
          <span>Placement key</span>
          <input
            className="input"
            value={channel.placement_key ?? ""}
            onChange={(event) =>
              onChange({ ...channel, placement_key: event.target.value })
            }
          />
        </label>
      </div>
    </div>
  );
}

function AuditList({ logs }: { logs: AuditLog[] }) {
  if (logs.length === 0) {
    return (
      <EmptyState
        title="No platform-control changes yet"
        description="Audit rows will appear here once admins edit the registry."
      />
    );
  }

  return (
    <div className="card">
      <div className="space-y-4">
        {logs.map((log) => (
          <div
            key={log.id}
            className="border border-border rounded-lg p-3 flex flex-col gap-1"
          >
            <div className="flex items-center justify-between gap-4">
              <div className="font-semibold text-sm">{log.action}</div>
              <div className="text-xs text-muted">
                {formatDateTime(log.created_at)}
              </div>
            </div>
            <div className="text-sm text-muted">
              {log.admin_name ?? "Admin"} changed {log.target_type}{" "}
              <span className="font-mono text-xs text-text">{log.target_id}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

export function PlatformControlPage() {
  const [search, setSearch] = useState("");
  const [featureFilter, setFeatureFilter] = useState<"all" | FeatureStatus>(
    "all",
  );
  const [selectedFeatureKey, setSelectedFeatureKey] = useState<string | null>(
    null,
  );
  const [featureForm, setFeatureForm] = useState<FeatureFormState>(
    emptyFeatureForm(),
  );
  const [featureFormError, setFeatureFormError] = useState<string | null>(null);

  const [selectedBlockKey, setSelectedBlockKey] = useState<string | null>(null);
  const [blockForm, setBlockForm] = useState<ContentBlockFormState>(
    emptyContentBlockForm(),
  );
  const [blockFormError, setBlockFormError] = useState<string | null>(null);

  const {
    data: platformFeatures = [],
    isLoading: isFeatureLoading,
    error: featureError,
    refetch: refetchFeatures,
  } = usePlatformFeatures();
  const {
    data: contentBlocks = [],
    isLoading: isBlockLoading,
    error: blockError,
    refetch: refetchBlocks,
  } = usePlatformContentBlocks();
  const { data: auditLogs = [] } = usePlatformFeatureAuditLogs();

  const upsertFeature = useUpsertPlatformFeature();
  const upsertContentBlock = useUpsertPlatformContentBlock();

  const filteredFeatures = useMemo(() => {
    const query = search.trim().toLowerCase();
    return platformFeatures.filter((feature) => {
      const matchesFilter =
        featureFilter === "all" ? true : feature.status === featureFilter;
      const matchesSearch =
        query.length === 0 ||
        [
          feature.feature_key,
          feature.display_name,
          feature.description ?? "",
          feature.default_route_key ?? "",
        ]
          .join(" ")
          .toLowerCase()
          .includes(query);
      return matchesFilter && matchesSearch;
    });
  }, [featureFilter, platformFeatures, search]);

  const selectedFeature = useMemo(
    () =>
      platformFeatures.find((feature) => feature.feature_key === selectedFeatureKey) ??
      null,
    [platformFeatures, selectedFeatureKey],
  );

  const selectedBlock = useMemo(
    () =>
      contentBlocks.find((block) => block.block_key === selectedBlockKey) ?? null,
    [contentBlocks, selectedBlockKey],
  );

  useEffect(() => {
    if (selectedFeature) {
      setFeatureForm(fromFeatureRecord(selectedFeature));
      setFeatureFormError(null);
      return;
    }
    if (selectedFeatureKey === null) {
      setFeatureForm(emptyFeatureForm());
      setFeatureFormError(null);
    }
  }, [selectedFeature, selectedFeatureKey]);

  useEffect(() => {
    if (selectedBlock) {
      setBlockForm(fromContentBlockRecord(selectedBlock));
      setBlockFormError(null);
      return;
    }
    if (selectedBlockKey === null) {
      setBlockForm(emptyContentBlockForm());
      setBlockFormError(null);
    }
  }, [selectedBlock, selectedBlockKey]);

  const enabledCount = platformFeatures.filter((item) => item.is_enabled).length;
  const mobileVisibleCount = platformFeatures.filter(
    (item) => item.mobile_channel.is_enabled && item.mobile_channel.is_visible,
  ).length;
  const webVisibleCount = platformFeatures.filter(
    (item) => item.web_channel.is_enabled && item.web_channel.is_visible,
  ).length;
  const activeBlocksCount = contentBlocks.filter((block) => block.is_active).length;

  const handleFeatureSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setFeatureFormError(null);

    try {
      await upsertFeature.mutateAsync({
        feature_key: featureForm.feature_key,
        display_name: featureForm.display_name,
        description: featureForm.description,
        status: featureForm.status,
        is_enabled: featureForm.is_enabled,
        navigation_group: featureForm.navigation_group,
        default_route_key: featureForm.default_route_key,
        admin_notes: featureForm.admin_notes,
        auth_required: featureForm.auth_required,
        dependency_config: parseJsonObject(
          featureForm.dependency_config_text,
          "Dependency config",
        ),
        rollout_config: parseJsonObject(
          featureForm.rollout_config_text,
          "Rollout config",
        ),
        schedule_start_at: fromDateTimeInputValue(featureForm.schedule_start_at),
        schedule_end_at: fromDateTimeInputValue(featureForm.schedule_end_at),
        mobile_channel: featureForm.mobile_channel,
        web_channel: featureForm.web_channel,
      });
      setSelectedFeatureKey(featureForm.feature_key.trim().toLowerCase());
    } catch (error) {
      setFeatureFormError(
        error instanceof Error ? error.message : "Could not save feature.",
      );
    }
  };

  const handleBlockSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setBlockFormError(null);

    try {
      await upsertContentBlock.mutateAsync({
        block_key: blockForm.block_key,
        block_type: blockForm.block_type,
        title: blockForm.title,
        content: parseJsonObject(blockForm.content_text, "Content block"),
        target_channel: blockForm.target_channel,
        is_active: blockForm.is_active,
        sort_order: blockForm.sort_order,
        feature_key: blockForm.feature_key || null,
        placement_key: blockForm.placement_key,
      });
      setSelectedBlockKey(blockForm.block_key.trim().toLowerCase());
    } catch (error) {
      setBlockFormError(
        error instanceof Error ? error.message : "Could not save block.",
      );
    }
  };

  if (isFeatureLoading && isBlockLoading) {
    return <LoadingState lines={10} />;
  }

  if (featureError || blockError) {
    return (
      <ErrorState
        title="Could not load platform control"
        description={
          featureError?.message ??
          blockError?.message ??
          "Please retry the registry query."
        }
        onRetry={() => {
          void refetchFeatures();
          void refetchBlocks();
        }}
      />
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Platform Control"
        subtitle="Centrally manage feature rollout, channel visibility, navigation placement, homepage composition, and audit history."
        actions={
          <>
            <button
              className="btn btn-secondary"
              onClick={() => setSelectedFeatureKey(null)}
            >
              <Plus size={16} />
              New Feature
            </button>
            <button
              className="btn btn-secondary"
              onClick={() => setSelectedBlockKey(null)}
            >
              <Layers3 size={16} />
              New Block
            </button>
          </>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        <KpiCard
          label="Registered Features"
          value={platformFeatures.length}
          icon={<Settings2 size={16} />}
        />
        <KpiCard
          label="Enabled Features"
          value={enabledCount}
          icon={<Navigation size={16} />}
        />
        <KpiCard
          label="Mobile Visible"
          value={mobileVisibleCount}
          icon={<MonitorSmartphone size={16} />}
        />
        <KpiCard
          label="Web Visible / Blocks"
          value={`${webVisibleCount} / ${activeBlocksCount}`}
          icon={<Globe size={16} />}
          format="raw"
        />
      </div>

      <div className="card">
        <div className="flex flex-col lg:flex-row lg:items-center gap-3 mb-4">
          <div className="relative flex-1">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
            <input
              className="input pl-10"
              placeholder="Search feature key, label, route, or notes"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
          </div>
          <select
            className="select"
            value={featureFilter}
            onChange={(event) =>
              setFeatureFilter(event.target.value as typeof featureFilter)
            }
          >
            <option value="all">All statuses</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="hidden">Hidden</option>
            <option value="beta">Beta</option>
            <option value="scheduled">Scheduled</option>
          </select>
        </div>

        {filteredFeatures.length === 0 ? (
          <EmptyState
            title="No matching features"
            description="Adjust the filters or create the next platform module."
          />
        ) : (
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Feature</th>
                  <th>Status</th>
                  <th>Mobile</th>
                  <th>Web</th>
                  <th>Route</th>
                  <th>Updated</th>
                </tr>
              </thead>
              <tbody>
                {filteredFeatures.map((feature) => (
                  <tr
                    key={feature.feature_key}
                    className={
                      selectedFeatureKey === feature.feature_key ? "bg-surface2" : ""
                    }
                    onClick={() => setSelectedFeatureKey(feature.feature_key)}
                    style={{ cursor: "pointer" }}
                  >
                    <td>
                      <div className="font-semibold">{feature.display_name}</div>
                      <div className="text-xs text-muted font-mono">
                        {feature.feature_key}
                      </div>
                    </td>
                    <td>
                      <div className="flex items-center gap-2">
                        <StatusChip status={feature.status} />
                        <span
                          className={`badge ${feature.is_enabled ? "badge-success" : "badge-danger"}`}
                        >
                          {feature.is_enabled ? "Enabled" : "Disabled"}
                        </span>
                      </div>
                    </td>
                    <td>
                      <ChannelPill label="App" channel={feature.mobile_channel} />
                    </td>
                    <td>
                      <ChannelPill label="Web" channel={feature.web_channel} />
                    </td>
                    <td className="font-mono text-xs">
                      {feature.default_route_key ?? feature.web_channel.route_key ?? "—"}
                    </td>
                    <td className="text-sm text-muted">
                      {formatDateTime(feature.updated_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,2fr)_minmax(320px,1fr)] gap-6">
        <form className="space-y-4" onSubmit={handleFeatureSubmit}>
          <div className="card">
            <div className="flex items-center justify-between gap-4 mb-4">
              <div>
                <h2 className="text-lg font-semibold">Feature Registry</h2>
                <p className="text-sm text-muted">
                  Manage feature metadata, rollout state, channel visibility, and routing.
                </p>
              </div>
              <button className="btn btn-primary" type="submit">
                <Save size={16} />
                Save Feature
              </button>
            </div>

            {featureFormError && (
              <div className="alert alert-error mb-4">{featureFormError}</div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <label className="form-field">
                <span>Feature key</span>
                <input
                  className="input"
                  value={featureForm.feature_key}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      feature_key: event.target.value,
                    }))
                  }
                  disabled={selectedFeature !== null}
                />
              </label>
              <label className="form-field">
                <span>Display name</span>
                <input
                  className="input"
                  value={featureForm.display_name}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      display_name: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field">
                <span>Status</span>
                <select
                  className="select"
                  value={featureForm.status}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      status: event.target.value as FeatureStatus,
                    }))
                  }
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="hidden">Hidden</option>
                  <option value="beta">Beta</option>
                  <option value="scheduled">Scheduled</option>
                </select>
              </label>
              <label className="form-field">
                <span>Navigation group</span>
                <input
                  className="input"
                  value={featureForm.navigation_group}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      navigation_group: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field md:col-span-2">
                <span>Description</span>
                <textarea
                  className="textarea"
                  rows={3}
                  value={featureForm.description}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      description: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field">
                <span>Default route</span>
                <input
                  className="input"
                  value={featureForm.default_route_key}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      default_route_key: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field">
                <span>Auth requirement</span>
                <div className="flex items-center gap-2 h-10">
                  <input
                    type="checkbox"
                    checked={featureForm.auth_required}
                    onChange={(event) =>
                      setFeatureForm((current) => ({
                        ...current,
                        auth_required: event.target.checked,
                      }))
                    }
                  />
                  <span className="text-sm text-muted">Require authenticated user</span>
                </div>
              </label>
              <label className="form-field">
                <span>Schedule start</span>
                <input
                  className="input"
                  type="datetime-local"
                  value={featureForm.schedule_start_at}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      schedule_start_at: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field">
                <span>Schedule end</span>
                <input
                  className="input"
                  type="datetime-local"
                  value={featureForm.schedule_end_at}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      schedule_end_at: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field md:col-span-2">
                <span>Admin notes</span>
                <textarea
                  className="textarea"
                  rows={2}
                  value={featureForm.admin_notes}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      admin_notes: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field md:col-span-2">
                <span>Dependency config JSON</span>
                <textarea
                  className="textarea font-mono"
                  rows={5}
                  value={featureForm.dependency_config_text}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      dependency_config_text: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field md:col-span-2">
                <span>Rollout config JSON</span>
                <textarea
                  className="textarea font-mono"
                  rows={5}
                  value={featureForm.rollout_config_text}
                  onChange={(event) =>
                    setFeatureForm((current) => ({
                      ...current,
                      rollout_config_text: event.target.value,
                    }))
                  }
                />
              </label>
            </div>
          </div>

          <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
            <FeatureChannelEditor
              label="Mobile App"
              icon={<MonitorSmartphone size={16} />}
              channel={featureForm.mobile_channel}
              onChange={(mobile_channel) =>
                setFeatureForm((current) => ({ ...current, mobile_channel }))
              }
            />
            <FeatureChannelEditor
              label="Website"
              icon={<Globe size={16} />}
              channel={featureForm.web_channel}
              onChange={(web_channel) =>
                setFeatureForm((current) => ({ ...current, web_channel }))
              }
            />
          </div>
        </form>

        <div className="space-y-6">
          <div className="card">
            <div className="flex items-center gap-2 mb-4">
              <Home size={16} />
              <h2 className="text-lg font-semibold">Homepage Blocks</h2>
            </div>

            {contentBlocks.length === 0 ? (
              <EmptyState
                title="No content blocks configured"
                description="Create the first admin-managed homepage or promo block."
              />
            ) : (
              <div className="space-y-3">
                {contentBlocks.map((block) => (
                  <button
                    key={block.block_key}
                    className={`w-full text-left border rounded-lg p-3 transition-colors ${
                      selectedBlockKey === block.block_key
                        ? "border-primary bg-surface2"
                        : "border-border hover:border-primary/40"
                    }`}
                    onClick={() => setSelectedBlockKey(block.block_key)}
                    type="button"
                  >
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <div className="font-semibold">{block.title}</div>
                        <div className="text-xs text-muted font-mono">
                          {block.block_key}
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <span
                          className={`badge ${block.is_active ? "badge-success" : "badge-danger"}`}
                        >
                          {block.is_active ? "Active" : "Inactive"}
                        </span>
                        <span className="badge badge-muted">
                          {block.target_channel}
                        </span>
                      </div>
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>

          <form className="card space-y-4" onSubmit={handleBlockSubmit}>
            <div className="flex items-center justify-between gap-4">
              <div>
                <h2 className="text-lg font-semibold">Content / Placement</h2>
                <p className="text-sm text-muted">
                  Control promo banners, home sections, and admin-managed placements.
                </p>
              </div>
              <button className="btn btn-primary" type="submit">
                <Save size={16} />
                Save Block
              </button>
            </div>

            {blockFormError && (
              <div className="alert alert-error">{blockFormError}</div>
            )}

            <label className="form-field">
              <span>Block key</span>
              <input
                className="input"
                value={blockForm.block_key}
                onChange={(event) =>
                  setBlockForm((current) => ({
                    ...current,
                    block_key: event.target.value,
                  }))
                }
                disabled={selectedBlock !== null}
              />
            </label>
            <label className="form-field">
              <span>Title</span>
              <input
                className="input"
                value={blockForm.title}
                onChange={(event) =>
                  setBlockForm((current) => ({
                    ...current,
                    title: event.target.value,
                  }))
                }
              />
            </label>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <label className="form-field">
                <span>Block type</span>
                <input
                  className="input"
                  value={blockForm.block_type}
                  onChange={(event) =>
                    setBlockForm((current) => ({
                      ...current,
                      block_type: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field">
                <span>Target channel</span>
                <select
                  className="select"
                  value={blockForm.target_channel}
                  onChange={(event) =>
                    setBlockForm((current) => ({
                      ...current,
                      target_channel: event.target.value as
                        | "mobile"
                        | "web"
                        | "both",
                    }))
                  }
                >
                  <option value="both">Both</option>
                  <option value="mobile">Mobile</option>
                  <option value="web">Web</option>
                </select>
              </label>
              <label className="form-field">
                <span>Feature assignment</span>
                <select
                  className="select"
                  value={blockForm.feature_key}
                  onChange={(event) =>
                    setBlockForm((current) => ({
                      ...current,
                      feature_key: event.target.value,
                    }))
                  }
                >
                  <option value="">No feature dependency</option>
                  {platformFeatures.map((feature) => (
                    <option key={feature.feature_key} value={feature.feature_key}>
                      {feature.display_name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="form-field">
                <span>Placement key</span>
                <input
                  className="input"
                  value={blockForm.placement_key}
                  onChange={(event) =>
                    setBlockForm((current) => ({
                      ...current,
                      placement_key: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="form-field">
                <span>Sort order</span>
                <input
                  className="input"
                  type="number"
                  value={blockForm.sort_order}
                  onChange={(event) =>
                    setBlockForm((current) => ({
                      ...current,
                      sort_order: Number(event.target.value || "0"),
                    }))
                  }
                />
              </label>
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={blockForm.is_active}
                  onChange={(event) =>
                    setBlockForm((current) => ({
                      ...current,
                      is_active: event.target.checked,
                    }))
                  }
                />
                Active block
              </label>
            </div>
            <label className="form-field">
              <span>Content JSON</span>
              <textarea
                className="textarea font-mono"
                rows={8}
                value={blockForm.content_text}
                onChange={(event) =>
                  setBlockForm((current) => ({
                    ...current,
                    content_text: event.target.value,
                  }))
                }
              />
            </label>
          </form>

          <div>
            <div className="flex items-center gap-2 mb-3">
              <History size={16} />
              <h2 className="text-lg font-semibold">Recent Audit History</h2>
            </div>
            <AuditList logs={auditLogs} />
          </div>
        </div>
      </div>
    </div>
  );
}
