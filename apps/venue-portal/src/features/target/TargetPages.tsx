import { type FormEvent, useEffect, useState } from "react";
import { Link, useLocation, useNavigate, useParams } from "react-router-dom";
import { safeHref, safeImageUrl } from "@fanzone/core";
import {
  BellRing,
  CheckCircle2,
  ClipboardCheck,
  ClipboardList,
  Coins,
  Gamepad2,
  ListChecks,
  Loader2,
  LockKeyhole,
  MonitorPlay,
  Pause,
  Play,
  QrCode,
  RefreshCcw,
  Settings,
  ShieldCheck,
  SkipForward,
  Square,
  Trophy,
  Users,
  Utensils,
  Wallet,
  XCircle,
} from "lucide-react";
import { EligibilityBadge } from "../../components/console/EligibilityBadge";
import { EmptyState } from "../../components/console/EmptyState";
import { StatusChip } from "../../components/console/StatusChip";
import { readableStatus } from "../../components/console/status";
import { useVenue } from "../../hooks/useVenueContext";
import {
  createVenueOfficialPool,
  useVenuePoolMatchOptions,
} from "../../hooks/useVenuePools";
import {
  closeVenuePoolJoining,
  createVenueGameSession,
  createVenueMenuCategory,
  createVenueMenuItem,
  fetchGameSessionControl,
  fetchGameTemplates,
  fetchVenueFetLedger,
  fetchVenueFetWallet,
  fetchVenueGameSessions,
  fetchVenueGameTeams,
  fetchVenueMenuRows,
  fetchVenuePoolDetail,
  fetchVenueScreenState,
  requestVenueFetTopUp,
  setVenueScreenState,
  settleVenuePool,
  settleVenueGameSession,
  updateGameSessionLifecycle,
  updateVenueMenuItem,
  verifyMusicBingoClaim,
  type GameTemplate,
  type VenueFetLedgerEntry,
  type VenueFetWallet,
  type VenueGameControl,
  type VenueGameSession,
  type VenueGameTeam,
  type VenuePoolDetail,
  type VenueScreenMode,
  type VenueScreenState,
} from "../../services/venueOperations";
import {
  AuditWarning,
  InlineLoading,
  LedgerRows,
  Notice,
  OperationalPage,
  SectionCard,
  WalletMetrics,
} from "./targetPageShared";
import {
  eligibilityRule,
  formatDate,
  nowLocalInputValue,
  screenModes,
  shortId,
  tvDisplayUrl,
  useAsyncData,
  userCode,
} from "./targetPageUtils";

export function MenuItemEditorPage() {
  const { venue } = useVenue();
  const { itemId } = useParams();
  const navigate = useNavigate();
  const isNew = !itemId;
  const menu = useAsyncData(
    () =>
      venue?.id
        ? fetchVenueMenuRows(venue.id)
        : Promise.resolve({ categories: [], items: [] }),
    [venue?.id, itemId],
    { categories: [], items: [] },
  );
  const existing = menu.data.items.find((item) => item.id === itemId);
  const [name, setName] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [categoryName, setCategoryName] = useState("");
  const [price, setPrice] = useState("0");
  const [currencyCode, setCurrencyCode] = useState("EUR");
  const [available, setAvailable] = useState(true);
  const [fetRate, setFetRate] = useState("");
  const [description, setDescription] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const sanitizedImageUrl = safeImageUrl(imageUrl);

  useEffect(() => {
    if (!existing) return;
    queueMicrotask(() => {
      setName(existing.name);
      setCategoryId(existing.category_id);
      setPrice(String(existing.price));
      setCurrencyCode(existing.currency_code);
      setAvailable(existing.is_available);
      setFetRate(
        existing.fet_earn_percent_override == null
          ? ""
          : String(existing.fet_earn_percent_override),
      );
      setDescription(existing.description ?? "");
      setImageUrl(existing.image_url ?? "");
    });
  }, [existing]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!venue?.id || !name.trim()) return;

    setSaving(true);
    setNotice(null);
    try {
      let nextCategoryId = categoryId;
      if (!nextCategoryId) {
        const category = await createVenueMenuCategory({
          venueId: venue.id,
          name: categoryName.trim() || "Menu",
          displayOrder: menu.data.categories.length + 1,
        });
        nextCategoryId = category.id;
      }

      if (isNew) {
        await createVenueMenuItem({
          venueId: venue.id,
          categoryId: nextCategoryId,
          name: name.trim(),
          description: description.trim() || null,
          price: Math.max(0, Number(price) || 0),
          currencyCode,
          imageUrl: sanitizedImageUrl,
          fetEarnPercentOverride: fetRate.trim()
            ? Math.max(0, Number(fetRate) || 0)
            : null,
          isAvailable: available,
          displayOrder: menu.data.items.length + 1,
        });
      } else if (itemId) {
        await updateVenueMenuItem({
          itemId,
          name: name.trim(),
          description: description.trim() || null,
          price: Math.max(0, Number(price) || 0),
          imageUrl: sanitizedImageUrl,
          fetEarnPercentOverride: fetRate.trim()
            ? Math.max(0, Number(fetRate) || 0)
            : null,
        });
      }

      setNotice("Menu item saved.");
      navigate("/menu");
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Could not save menu item.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <OperationalPage
      eyebrow="Menu"
      title={isNew ? "Add menu item" : "Edit menu item"}
      description="Create and maintain orderable menu items with pricing, availability, item-level FET earn controls, and a customer-facing card preview."
      icon={<Utensils size={26} />}
      status={isNew ? "draft" : existing?.is_available ? "active" : "closed"}
      primaryAction={{ label: "Open Menu Manager", to: "/menu" }}
      secondaryAction={{
        label: "Reward Settings",
        to: "/settings/fet-rewards",
      }}
      metrics={[
        {
          label: "Active categories",
          value: String(menu.data.categories.length),
          detail: "Loaded from live menu categories.",
        },
        {
          label: "Item mode",
          value: isNew ? "Create" : "Edit",
          detail: "Writes to venue menu tables.",
        },
        {
          label: "FET rewards",
          value: "Configurable",
          detail: "Optional item-level override.",
        },
        {
          label: "Venue scope",
          value: "Locked",
          detail: "Menu items belong to this venue.",
        },
      ]}
    >
      {menu.loading && <InlineLoading />}
      <Notice
        message={notice}
        tone={notice?.startsWith("Could") ? "danger" : "success"}
      />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <SectionCard
          title="Item setup"
          detail="This form writes to the live venue menu record."
        >
          <form className="space-y-5" onSubmit={handleSubmit}>
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <label className="block">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Item name
                </span>
                <input
                  className="input mt-2"
                  value={name}
                  onChange={(event) => setName(event.target.value)}
                  required
                />
              </label>
              <label className="block">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Category
                </span>
                <select
                  className="input mt-2"
                  value={categoryId}
                  onChange={(event) => setCategoryId(event.target.value)}
                >
                  <option value="">New / default category</option>
                  {menu.data.categories.map((category) => (
                    <option key={category.id} value={category.id}>
                      {category.name}
                    </option>
                  ))}
                </select>
              </label>
              {!categoryId && (
                <label className="block md:col-span-2">
                  <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                    New category name
                  </span>
                  <input
                    className="input mt-2"
                    value={categoryName}
                    onChange={(event) => setCategoryName(event.target.value)}
                    placeholder="Menu"
                  />
                </label>
              )}
              <label className="block">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Price
                </span>
                <input
                  className="input mt-2"
                  type="number"
                  min={0}
                  step="0.01"
                  value={price}
                  onChange={(event) => setPrice(event.target.value)}
                />
              </label>
              <label className="block">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Currency
                </span>
                <select
                  className="input mt-2"
                  value={currencyCode}
                  onChange={(event) => setCurrencyCode(event.target.value)}
                >
                  <option value="EUR">EUR</option>
                  <option value="RWF">RWF</option>
                  <option value="USD">USD</option>
                </select>
              </label>
              <label className="block">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Availability
                </span>
                <select
                  className="input mt-2"
                  value={available ? "available" : "unavailable"}
                  onChange={(event) =>
                    setAvailable(event.target.value === "available")
                  }
                >
                  <option value="available">Available</option>
                  <option value="unavailable">Unavailable</option>
                </select>
              </label>
              <label className="block">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  FET earn rate
                </span>
                <input
                  className="input mt-2"
                  type="number"
                  min={0}
                  value={fetRate}
                  onChange={(event) => setFetRate(event.target.value)}
                  placeholder="Optional override"
                />
              </label>
              <label className="block md:col-span-2">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Description
                </span>
                <input
                  className="input mt-2"
                  value={description}
                  onChange={(event) => setDescription(event.target.value)}
                  placeholder="Customer-facing description"
                />
              </label>
              <label className="block md:col-span-2">
                <span className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Image URL
                </span>
                <input
                  className="input mt-2"
                  value={imageUrl}
                  onChange={(event) => setImageUrl(event.target.value)}
                  placeholder="Optional image URL"
                />
              </label>
            </div>
            <button
              className="btn btn-primary"
              type="submit"
              disabled={saving || !venue?.id || !name.trim()}
            >
              {saving ? (
                <Loader2 className="animate-spin" size={16} />
              ) : (
                <CheckCircle2 size={16} />
              )}
              Save item
            </button>
          </form>
        </SectionCard>

        <SectionCard
          title="Customer card preview"
          detail="The preview uses the same hierarchy as the guest app menu card."
        >
          <div className="ops-panel p-5">
            <div className="aspect-[4/3] overflow-hidden rounded-2xl border border-dashed border-border bg-surface3">
              {sanitizedImageUrl && (
                <img
                  className="h-full w-full object-cover"
                  src={sanitizedImageUrl}
                  alt=""
                />
              )}
            </div>
            <div className="mt-5 flex items-start justify-between gap-4">
              <div>
                <p className="text-2xl font-black">{name || "New menu item"}</p>
                <p className="mt-2 text-base font-semibold text-textSecondary">
                  {currencyCode} {(Number(price) || 0).toFixed(2)} ·{" "}
                  {available ? "Available" : "Unavailable"}
                </p>
              </div>
              <StatusChip status={available ? "active" : "closed"} />
            </div>
          </div>
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

export function CreatePoolPage() {
  const { venue } = useVenue();
  const navigate = useNavigate();
  const matchOptions = useVenuePoolMatchOptions(venue?.id);
  const wallet = useAsyncData<VenueFetWallet | null>(
    () => (venue?.id ? fetchVenueFetWallet(venue.id) : Promise.resolve(null)),
    [venue?.id],
    null,
  );
  const [matchId, setMatchId] = useState("");
  const [title, setTitle] = useState("");
  const [barStake, setBarStake] = useState("0");
  const [participantStake, setParticipantStake] = useState("5");
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const selected = matchOptions.options.find(
    (option) => option.match_id === matchId,
  );
  const walletBalance = wallet.data?.availableBalanceFet ?? 0;
  const insufficient = Number(barStake) > walletBalance;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!venue?.id || !matchId || insufficient) return;

    setSaving(true);
    setNotice(null);
    try {
      await createVenueOfficialPool({
        venueId: venue.id,
        matchId,
        title,
        entryFeeFet: Math.max(1, Number(participantStake) || 1),
        stakeMinFet: Math.max(1, Number(participantStake) || 1),
        stakeMaxFet: Math.max(1, Number(participantStake) || 1),
        creatorRewardFet: 0,
        barStakeFet: Math.max(0, Number(barStake) || 0),
      });
      navigate("/pools");
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Could not create pool.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <OperationalPage
      eyebrow="Prediction pools"
      title="Create prediction pool"
      description="Create a staked football pool by selecting a match, staking bar FET, setting the participant stake, and confirming the eligibility rule."
      icon={<Trophy size={26} />}
      status="draft"
      primaryAction={{ label: "Open Pools", to: "/pools" }}
      secondaryAction={{ label: "Open Wallet", to: "/wallet" }}
      metrics={[
        {
          label: "Wallet balance",
          value: `${walletBalance.toLocaleString()} FET`,
          detail: "Bar stake is checked before creation.",
        },
        {
          label: "Pool type",
          value: "Staked",
          detail: "Creator and participant stakes required.",
        },
        { label: "Options", value: "3", detail: "Home win, draw, away win." },
        {
          label: "Settlement",
          value: "Eligible only",
          detail: "Winners without qualifying orders are not paid.",
        },
      ]}
      rule
    >
      <Notice message={notice} tone="danger" />
      <form
        className="grid grid-cols-1 gap-5 xl:grid-cols-5"
        onSubmit={handleSubmit}
      >
        <SectionCard title="1. Select match">
          <select
            className="input"
            value={matchId}
            onChange={(event) => setMatchId(event.target.value)}
            required
          >
            <option value="">
              {matchOptions.loading
                ? "Loading matches..."
                : "Select curated match"}
            </option>
            {matchOptions.options.map((option) => (
              <option
                key={`${option.match_id}-${option.venue_id ?? "global"}`}
                value={option.match_id}
                disabled={!!option.official_pool_id}
              >
                {option.match_label} · {formatDate(option.kickoff_at)}
                {option.official_pool_id ? " · official pool exists" : ""}
              </option>
            ))}
          </select>
          <input
            className="input mt-3"
            value={title}
            onChange={(event) => setTitle(event.target.value)}
            placeholder="Pool title, optional"
          />
          <p className="mt-3 text-sm font-bold text-textSecondary">
            {selected?.competition_name ?? "Curated match list"}
          </p>
        </SectionCard>
        <SectionCard title="2. Set stake">
          <input
            className="input"
            type="number"
            min={0}
            value={barStake}
            onChange={(event) => setBarStake(event.target.value)}
            placeholder="Bar stake FET"
          />
          <input
            className="input mt-3"
            type="number"
            min={1}
            value={participantStake}
            onChange={(event) => setParticipantStake(event.target.value)}
            placeholder="Participant stake FET"
          />
          {insufficient && (
            <p className="mt-3 text-sm font-black text-danger">
              Insufficient venue FET balance.
            </p>
          )}
        </SectionCard>
        <SectionCard title="3. Rules">
          <AuditWarning>{eligibilityRule}</AuditWarning>
        </SectionCard>
        <SectionCard title="4. Preview">
          <p className="text-3xl font-black">
            {(Number(barStake) || 0).toLocaleString()} FET
          </p>
          <p className="mt-2 text-sm font-bold text-textSecondary">
            Initial bar stake, before participant stakes.
          </p>
        </SectionCard>
        <SectionCard title="5. Confirm">
          <AuditWarning>
            Confirming deducts the bar stake from the venue FET wallet and
            writes ledger entries.
          </AuditWarning>
          <button
            className="btn btn-primary mt-4 w-full"
            type="submit"
            disabled={saving || !matchId || insufficient}
          >
            {saving ? (
              <Loader2 className="animate-spin" size={16} />
            ) : (
              <Trophy size={16} />
            )}
            Create pool
          </button>
        </SectionCard>
      </form>
    </OperationalPage>
  );
}

export function PoolDetailPage() {
  const { venue } = useVenue();
  const { poolId } = useParams();
  const detail = useAsyncData<VenuePoolDetail | null>(
    () =>
      venue?.id && poolId
        ? fetchVenuePoolDetail(venue.id, poolId)
        : Promise.resolve(null),
    [venue?.id, poolId],
    null,
  );
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const pool = detail.data?.pool;

  async function run(action: () => Promise<unknown>, success: string) {
    setBusy(true);
    setNotice(null);
    try {
      await action();
      setNotice(success);
      detail.refresh();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Action failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <OperationalPage
      eyebrow="Prediction pools"
      title={pool?.matchLabel ?? "Pool detail"}
      description="Control one venue-linked prediction pool with match status, stakes, participant camps, eligibility, TV display tools, and audit history."
      icon={<Trophy size={26} />}
      status={pool?.status ?? "scheduled"}
      primaryAction={{ label: "Back to Pools", to: "/pools" }}
      secondaryAction={{
        label: "Settle Pool",
        to: poolId ? `/pools/${poolId}/settle` : undefined,
      }}
      metrics={[
        {
          label: "Participants",
          value: String(pool?.totalMembers ?? 0),
          detail: "Joined users in this venue pool.",
        },
        {
          label: "Total pot",
          value: `${(pool?.totalStakedFet ?? 0).toLocaleString()} FET`,
          detail: "Participant stake total.",
        },
        {
          label: "Bar stake",
          value: `${(pool?.barStakeFet ?? 0).toLocaleString()} FET`,
          detail: "Venue wallet stake.",
        },
        {
          label: "Kickoff",
          value: pool?.kickoffAt ? formatDate(pool.kickoffAt) : "Unset",
          detail: pool?.competitionName ?? "Curated match.",
        },
      ]}
      rule
    >
      {detail.loading && <InlineLoading />}
      <Notice
        message={detail.error ?? notice}
        tone={detail.error || notice?.includes("failed") ? "danger" : "success"}
      />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <SectionCard
          title="Prediction camps"
          detail="Distribution stays split into home win, draw, and away win only."
        >
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            {(pool?.camps ?? []).map((camp) => (
              <article key={camp.id} className="ops-panel p-5">
                <p className="text-2xl font-black">{camp.label}</p>
                <p className="mt-3 text-base font-bold text-textSecondary">
                  {camp.memberCount} users · {camp.totalStakedFet} FET
                </p>
                <div className="mt-4">
                  <EligibilityBadge
                    state={
                      camp.isWinningCamp ? "settled" : "settlement_pending"
                    }
                  />
                </div>
              </article>
            ))}
          </div>
        </SectionCard>
        <SectionCard
          title="Pool actions"
          detail="Actions are permission-gated and auditable."
        >
          <div className="space-y-3">
            <button
              className="btn btn-secondary w-full"
              type="button"
              disabled={busy || !venue?.id || !poolId}
              onClick={() =>
                run(
                  () =>
                    setVenueScreenState({
                      venueId: venue!.id,
                      mode: "pool",
                      activePoolId: poolId,
                    }),
                  "Pool pushed to TV screen.",
                )
              }
            >
              Show on TV screen
              <MonitorPlay size={16} />
            </button>
            <button
              className="btn btn-secondary w-full"
              type="button"
              disabled={
                busy ||
                !poolId ||
                pool?.status === "settled" ||
                pool?.status === "cancelled"
              }
              onClick={() =>
                run(
                  () => closeVenuePoolJoining(poolId!),
                  "Pool joining closed.",
                )
              }
            >
              Close joining
              <LockKeyhole size={16} />
            </button>
            <Link
              className="btn btn-primary w-full"
              to={poolId ? `/pools/${poolId}/settle` : "/pools"}
            >
              Review settlement
              <ClipboardCheck size={16} />
            </Link>
            <AuditWarning>
              Pool updates record staff actor, venue, pool ID, and ledger
              references.
            </AuditWarning>
          </div>
        </SectionCard>
        <SectionCard
          title="Participants"
          detail="Participant rows use 6-digit IDs where names are not required."
        >
          {detail.data?.entries.length ? (
            <div className="space-y-3">
              {detail.data.entries.map((entry) => (
                <div
                  key={entry.id}
                  className="grid grid-cols-1 gap-3 rounded-2xl border border-border bg-surface2 p-4 md:grid-cols-[1fr_120px_120px]"
                >
                  <p className="text-lg font-black">
                    User {userCode(entry.userId)}
                  </p>
                  <p className="text-sm font-black text-textSecondary">
                    {entry.amountFet} FET
                  </p>
                  <StatusChip status={entry.status} />
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={<Users size={30} />}
              title="No participants yet"
              message="Joined users appear here after staking into this venue pool."
            />
          )}
        </SectionCard>
        <SectionCard title="Settlement state">
          {detail.data?.settlement ? (
            <div className="space-y-3">
              <StatusChip status={detail.data.settlement.status} />
              <p className="text-3xl font-black">
                {detail.data.settlement.totalPaidFet.toLocaleString()} FET paid
              </p>
              <p className="text-base font-bold text-textSecondary">
                {detail.data.settlement.winnersCount} winners ·{" "}
                {detail.data.settlement.payoutPerWinnerFet} FET each
              </p>
            </div>
          ) : (
            <EmptyState
              icon={<ClipboardList size={30} />}
              title="No settlement yet"
              message="Settlement appears after final result and eligibility validation."
            />
          )}
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

export function PoolSettlementPage() {
  const { venue } = useVenue();
  const { poolId } = useParams();
  const detail = useAsyncData<VenuePoolDetail | null>(
    () =>
      venue?.id && poolId
        ? fetchVenuePoolDetail(venue.id, poolId)
        : Promise.resolve(null),
    [venue?.id, poolId],
    null,
  );
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSettle() {
    if (!poolId) return;
    setBusy(true);
    setNotice(null);
    try {
      await settleVenuePool(poolId);
      setNotice("Settlement completed or confirmed idempotently.");
      detail.refresh();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Could not settle pool.");
    } finally {
      setBusy(false);
    }
  }

  const pool = detail.data?.pool;
  const settlement = detail.data?.settlement;

  return (
    <OperationalPage
      eyebrow="Prediction pools"
      title="Pool settlement"
      description="Review final result, eligible winners, ineligible winners, payout per winner, and ledger entries before settlement."
      icon={<ClipboardCheck size={26} />}
      status={settlement?.status ?? "settling"}
      primaryAction={{
        label: "Back to Pool",
        to: poolId ? `/pools/${poolId}` : "/pools",
      }}
      secondaryAction={{ label: "Back to Pools", to: "/pools" }}
      metrics={[
        {
          label: "Pool",
          value: pool ? shortId(pool.id) : "None",
          detail: pool?.matchLabel ?? "Venue-scoped pool.",
        },
        {
          label: "Participants",
          value: String(detail.data?.entries.length ?? 0),
          detail: "Eligibility enforced server-side.",
        },
        {
          label: "Paid FET",
          value: `${(settlement?.totalPaidFet ?? 0).toLocaleString()} FET`,
          detail: "Ledger-backed payout total.",
        },
        {
          label: "Duplicate payout",
          value: "Blocked",
          detail: "Settlement RPC is idempotent.",
        },
      ]}
      rule
    >
      {detail.loading && <InlineLoading />}
      <Notice
        message={detail.error ?? notice}
        tone={detail.error || notice?.includes("Could") ? "danger" : "success"}
      />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[0.8fr_1.2fr]">
        <SectionCard title="Final result">
          <div className="space-y-4">
            <p className="text-3xl font-black">{pool?.matchLabel ?? "Pool"}</p>
            <p className="text-base font-bold text-textSecondary">
              {pool?.competitionName ?? "Curated match"} ·{" "}
              {formatDate(pool?.kickoffAt)}
            </p>
            <AuditWarning>
              Settlement pays eligible winners only and leaves ineligible
              winners visible but unpaid.
            </AuditWarning>
            <button
              className="btn btn-primary w-full"
              type="button"
              onClick={handleSettle}
              disabled={busy || !poolId}
            >
              {busy ? (
                <Loader2 className="animate-spin" size={16} />
              ) : (
                <ClipboardCheck size={16} />
              )}
              Confirm settlement
            </button>
          </div>
        </SectionCard>
        <SectionCard title="Ledger preview">
          {settlement ? (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
              <div className="ops-panel p-5">
                <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Winners
                </p>
                <p className="mt-2 text-3xl font-black">
                  {settlement.winnersCount}
                </p>
              </div>
              <div className="ops-panel p-5">
                <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Paid
                </p>
                <p className="mt-2 text-3xl font-black">
                  {settlement.totalPaidFet} FET
                </p>
              </div>
              <div className="ops-panel p-5">
                <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Each
                </p>
                <p className="mt-2 text-3xl font-black">
                  {settlement.payoutPerWinnerFet} FET
                </p>
              </div>
            </div>
          ) : (
            <EmptyState
              icon={<ClipboardList size={30} />}
              title="No settlement ledger generated yet"
              message="Confirm settlement after final result is available."
            />
          )}
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

export function GamesPage() {
  const { venue } = useVenue();
  const sessions = useAsyncData<VenueGameSession[]>(
    () => (venue?.id ? fetchVenueGameSessions(venue.id) : Promise.resolve([])),
    [venue?.id],
    [],
  );
  const templates = useAsyncData<GameTemplate[]>(fetchGameTemplates, [], []);

  return (
    <OperationalPage
      eyebrow="Games"
      title="Centralized games"
      description="Start or schedule platform-managed Bar Trivia, Fan Trivia, Music Bingo, and Song Guess sessions for the selected venue."
      icon={<Gamepad2 size={26} />}
      status="scheduled"
      primaryAction={{ label: "Start Game", to: "/games/new" }}
      secondaryAction={{ label: "Open Screen", to: "/screen" }}
      metrics={[
        {
          label: "Active sessions",
          value: String(
            sessions.data.filter((session) =>
              ["scheduled", "lobby", "live"].includes(session.status),
            ).length,
          ),
          detail: "Venue-linked only.",
        },
        {
          label: "Game templates",
          value: String(templates.data.length),
          detail: "Centralized platform list.",
        },
        {
          label: "Question rounds",
          value: "20",
          detail: "Selected once at session start.",
        },
        {
          label: "Scoring",
          value: "First correct",
          detail: "Later correct answers earn 0.",
        },
      ]}
      rule
    >
      {(sessions.loading || templates.loading) && <InlineLoading />}
      <Notice message={sessions.error ?? templates.error} tone="danger" />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1fr_1fr]">
        <SectionCard
          title="Available game templates"
          detail="Bars choose approved templates. They do not create custom game logic."
        >
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {templates.data.map((template) => (
              <article key={template.id} className="ops-panel p-5">
                <div className="flex items-center justify-between gap-4">
                  <p className="text-xl font-black">{template.name}</p>
                  <StatusChip status="active" label="Approved" />
                </div>
                <p className="mt-3 text-base font-semibold leading-7 text-textSecondary">
                  {readableStatus(template.category)} · reward pool reserved
                  from venue wallet when a session is created.
                </p>
              </article>
            ))}
          </div>
        </SectionCard>
        <SectionCard title="Active and scheduled sessions">
          {sessions.data.length ? (
            <div className="space-y-3">
              {sessions.data.map((session) => (
                <div
                  key={session.id}
                  className="rounded-2xl border border-border bg-surface2 p-4"
                >
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="text-xl font-black">
                        {session.templateName}
                      </p>
                      <p className="text-sm font-bold text-textSecondary">
                        {formatDate(session.scheduledStartAt)}
                      </p>
                    </div>
                    <StatusChip status={session.status} />
                  </div>
                  <div className="mt-4 flex flex-wrap gap-3">
                    <Link
                      className="btn btn-primary"
                      to={`/games/${session.id}/control`}
                    >
                      Control
                    </Link>
                    <Link className="btn btn-secondary" to="/screen">
                      Show on Screen
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={<Gamepad2 size={30} />}
              title="No live session selected"
              message="Start a platform game to create a session, QR, team lobby, and TV display."
            />
          )}
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

export function StartGamePage() {
  const { venue } = useVenue();
  const navigate = useNavigate();
  const templates = useAsyncData<GameTemplate[]>(fetchGameTemplates, [], []);
  const wallet = useAsyncData<VenueFetWallet | null>(
    () => (venue?.id ? fetchVenueFetWallet(venue.id) : Promise.resolve(null)),
    [venue?.id],
    null,
  );
  const [templateId, setTemplateId] = useState("");
  const [reward, setReward] = useState("0");
  const [startMode, setStartMode] = useState<"now" | "later">("now");
  const [scheduledAt, setScheduledAt] = useState(nowLocalInputValue());
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const insufficient = Number(reward) > (wallet.data?.availableBalanceFet ?? 0);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!venue?.id || !templateId || insufficient) return;

    setSaving(true);
    setNotice(null);
    try {
      await createVenueGameSession({
        venueId: venue.id,
        templateId,
        scheduledStartAt:
          startMode === "now"
            ? new Date().toISOString()
            : new Date(scheduledAt).toISOString(),
        rewardFet: Math.max(0, Number(reward) || 0),
      });
      navigate("/games");
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Could not create game session.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <OperationalPage
      eyebrow="Games"
      title="Start game"
      description="Choose a centralized game, reserve the reward pool from the venue FET wallet, schedule it, preview rules, and generate a join QR."
      icon={<Gamepad2 size={26} />}
      status="draft"
      primaryAction={{ label: "Back to Games", to: "/games" }}
      secondaryAction={{ label: "Open Wallet", to: "/wallet" }}
      metrics={[
        {
          label: "Wallet balance",
          value: `${(wallet.data?.availableBalanceFet ?? 0).toLocaleString()} FET`,
          detail: "Reward pool cannot exceed balance.",
        },
        {
          label: "Minimum teams",
          value: "2",
          detail: "Required before live play.",
        },
        {
          label: "Question games",
          value: "20",
          detail: "Approved questions persisted on session.",
        },
        {
          label: "Winner",
          value: "Top FET score",
          detail: "No faster-answer bonus.",
        },
      ]}
      rule
    >
      <Notice message={notice} tone="danger" />
      <form
        className="grid grid-cols-1 gap-5 xl:grid-cols-4"
        onSubmit={handleSubmit}
      >
        <SectionCard title="1. Choose game">
          <select
            className="input"
            value={templateId}
            onChange={(event) => setTemplateId(event.target.value)}
            required
          >
            <option value="">
              {templates.loading ? "Loading templates..." : "Select template"}
            </option>
            {templates.data.map((template) => (
              <option key={template.id} value={template.id}>
                {template.name}
              </option>
            ))}
          </select>
        </SectionCard>
        <SectionCard title="2. Set reward">
          <input
            className="input"
            type="number"
            min={0}
            value={reward}
            onChange={(event) => setReward(event.target.value)}
          />
          {insufficient && (
            <p className="mt-3 text-sm font-black text-danger">
              Insufficient venue FET balance.
            </p>
          )}
        </SectionCard>
        <SectionCard title="3. Schedule">
          <select
            className="input"
            value={startMode}
            onChange={(event) =>
              setStartMode(event.target.value as "now" | "later")
            }
          >
            <option value="now">Start now</option>
            <option value="later">Schedule later</option>
          </select>
          {startMode === "later" && (
            <input
              className="input mt-3"
              type="datetime-local"
              value={scheduledAt}
              onChange={(event) => setScheduledAt(event.target.value)}
            />
          )}
        </SectionCard>
        <SectionCard title="4. Confirm">
          <AuditWarning>
            Game creation reserves reward FET and writes venue wallet ledger
            rows.
          </AuditWarning>
          <button
            className="btn btn-primary mt-4 w-full"
            type="submit"
            disabled={saving || !templateId || insufficient}
          >
            {saving ? (
              <Loader2 className="animate-spin" size={16} />
            ) : (
              <Gamepad2 size={16} />
            )}
            Create session
          </button>
        </SectionCard>
      </form>
    </OperationalPage>
  );
}

export function GameControlPage() {
  const { sessionId } = useParams();
  const control = useAsyncData<VenueGameControl | null>(
    () =>
      sessionId ? fetchGameSessionControl(sessionId) : Promise.resolve(null),
    [sessionId],
    null,
  );
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function lifecycle(
    action: "start" | "pause" | "resume" | "next_round" | "end",
  ) {
    if (!sessionId) return;
    setBusy(true);
    setNotice(null);
    try {
      await updateGameSessionLifecycle(sessionId, action);
      setNotice(`${readableStatus(action)} complete.`);
      control.refresh();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Game action failed.");
    } finally {
      setBusy(false);
    }
  }

  async function reviewBingoClaim(claimId: string, approved: boolean) {
    setBusy(true);
    setNotice(null);
    try {
      await verifyMusicBingoClaim(claimId, approved, approved ? 1 : 0);
      setNotice(approved ? "Bingo claim verified." : "Bingo claim rejected.");
      control.refresh();
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Bingo claim review failed.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function settleGame() {
    if (!sessionId) return;
    setBusy(true);
    setNotice(null);
    try {
      await settleVenueGameSession(sessionId);
      setNotice(
        "Game settled. Eligible winners were paid from the venue reward pool.",
      );
      control.refresh();
    } catch (err) {
      setNotice(err instanceof Error ? err.message : "Game settlement failed.");
    } finally {
      setBusy(false);
    }
  }

  const session = control.data?.session;
  const teams = control.data?.teams ?? [];
  const bingoClaims = control.data?.bingoClaims ?? [];
  const hasSettlement =
    session?.metadata &&
    typeof session.metadata === "object" &&
    !Array.isArray(session.metadata)
      ? (session.metadata as Record<string, unknown>).settlement
      : null;

  return (
    <OperationalPage
      eyebrow="Games"
      title={session?.templateName ?? "Game control"}
      description="Live host console for rounds, questions, bingo claims, teams, leaderboard, eligibility, and TV screen state."
      icon={<Gamepad2 size={26} />}
      status={session?.status ?? "live"}
      primaryAction={{ label: "Back to Games", to: "/games" }}
      secondaryAction={{ label: "Open Screen", to: "/screen" }}
      metrics={[
        {
          label: "Session",
          value: session ? shortId(session.id) : "None",
          detail: "Venue-scoped live session.",
        },
        {
          label: "Round",
          value: `${session?.currentQuestionOrdinal ?? 0} / ${session?.selectedQuestionCount ?? 20}`,
          detail: "Persisted session questions.",
        },
        {
          label: "Teams",
          value: String(teams.length),
          detail: "Minimum 2 before competitive play.",
        },
        {
          label: "Scoring",
          value: "First correct",
          detail: "Later correct answers earn 0.",
        },
      ]}
      rule
    >
      {control.loading && <InlineLoading />}
      <Notice
        message={control.error ?? notice}
        tone={
          control.error || notice?.includes("failed") ? "danger" : "success"
        }
      />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1fr_420px]">
        <SectionCard
          title="Live round panel"
          detail="Use this surface during trivia, song guess, and bingo hosting."
        >
          <div className="rounded-3xl border border-border bg-surface3 p-6">
            <div className="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  Current prompt
                </p>
                <p className="mt-3 text-3xl font-black">
                  {control.data?.currentQuestion?.prompt ??
                    "No current question loaded"}
                </p>
              </div>
              <StatusChip status={session?.status ?? "pending"} />
            </div>
            <div className="mt-6 grid grid-cols-1 gap-3 md:grid-cols-2">
              <button
                className="btn btn-secondary"
                type="button"
                disabled={busy}
                onClick={() => lifecycle("start")}
              >
                <Play size={16} /> Start
              </button>
              <button
                className="btn btn-secondary"
                type="button"
                disabled={busy}
                onClick={() => lifecycle("pause")}
              >
                <Pause size={16} /> Pause
              </button>
              <button
                className="btn btn-secondary"
                type="button"
                disabled={busy}
                onClick={() => lifecycle("resume")}
              >
                <RefreshCcw size={16} /> Resume
              </button>
              <button
                className="btn btn-secondary"
                type="button"
                disabled={busy}
                onClick={() => lifecycle("next_round")}
              >
                <SkipForward size={16} /> Next round
              </button>
              <button
                className="btn bg-danger/10 text-danger border border-danger/20 md:col-span-2"
                type="button"
                disabled={busy}
                onClick={() => lifecycle("end")}
              >
                <Square size={16} /> End game
              </button>
              <button
                className="btn btn-primary md:col-span-2"
                type="button"
                disabled={busy || session?.status === "settled"}
                onClick={settleGame}
              >
                <Coins size={16} /> Settle eligible winners
              </button>
            </div>
            {Boolean(hasSettlement) && (
              <div className="mt-5 rounded-2xl border border-success/20 bg-success/10 p-4 text-sm font-bold text-success">
                Settlement recorded. Eligible winners and ineligible winners are
                stored on the session audit metadata.
              </div>
            )}
          </div>
        </SectionCard>
        <SectionCard title="Leaderboard and eligibility">
          {teams.length ? (
            <div className="space-y-3">
              {teams.map((team) => (
                <div
                  key={team.id}
                  className="rounded-2xl border border-border bg-surface2 p-4"
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <p className="text-xl font-black">{team.name}</p>
                      <p className="text-sm font-bold text-textSecondary">
                        {team.memberCount} members · invite{" "}
                        {team.inviteCode ?? "pending"}
                      </p>
                    </div>
                    <p className="text-3xl font-black">{team.scoreFet} FET</p>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={<Users size={30} />}
              title="No teams loaded"
              message="Teams appear here after guests join or create teams inside the venue game session."
            />
          )}
        </SectionCard>
        {session?.templateId === "music_bingo" && (
          <SectionCard
            title="Music Bingo claims"
            detail="Claims require host verification before score changes. The app does not stream music."
          >
            {bingoClaims.length ? (
              <div className="space-y-3">
                {bingoClaims.map((claim) => (
                  <div
                    key={claim.id}
                    className="rounded-2xl border border-border bg-surface2 p-4"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div>
                        <p className="text-xl font-black">{claim.teamName}</p>
                        <p className="text-sm font-bold text-textSecondary">
                          Claim {shortId(claim.id)} ·{" "}
                          {readableStatus(claim.status)} · {claim.awardedFet}{" "}
                          FET
                        </p>
                      </div>
                      <div className="flex flex-wrap gap-2">
                        <button
                          className="btn btn-secondary"
                          type="button"
                          disabled={busy || claim.status !== "submitted"}
                          onClick={() => reviewBingoClaim(claim.id, true)}
                        >
                          <CheckCircle2 size={16} /> Verify
                        </button>
                        <button
                          className="btn bg-danger/10 text-danger border border-danger/20"
                          type="button"
                          disabled={busy || claim.status !== "submitted"}
                          onClick={() => reviewBingoClaim(claim.id, false)}
                        >
                          <XCircle size={16} /> Reject
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <EmptyState
                icon={<ClipboardCheck size={30} />}
                title="No bingo claims"
                message="Submitted Music Bingo claims appear here for host verification."
              />
            )}
          </SectionCard>
        )}
      </div>
    </OperationalPage>
  );
}

export function TeamsPage() {
  const { venue } = useVenue();
  const teams = useAsyncData<VenueGameTeam[]>(
    () => (venue?.id ? fetchVenueGameTeams(venue.id) : Promise.resolve([])),
    [venue?.id],
    [],
  );

  return (
    <OperationalPage
      eyebrow="Teams"
      title="Teams and camps"
      description="Manage teams created inside venue game sessions, including members, invite codes, FET score, and eligibility counts."
      icon={<Users size={26} />}
      status="scheduled"
      primaryAction={{ label: "Open Participants", to: "/participants" }}
      secondaryAction={{ label: "Start Game", to: "/games/new" }}
      metrics={[
        {
          label: "Teams",
          value: String(teams.data.length),
          detail: "Linked to venue games.",
        },
        {
          label: "Minimum",
          value: "2 teams",
          detail: "Required before game settlement.",
        },
        {
          label: "Members",
          value: "6-digit IDs",
          detail: "No names required.",
        },
        {
          label: "Eligibility",
          value: "Per member",
          detail: "Qualifying order controls payout.",
        },
      ]}
      rule
    >
      {teams.loading && <InlineLoading />}
      <Notice message={teams.error} tone="danger" />
      <SectionCard title="Active teams">
        {teams.data.length ? (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {teams.data.map((team) => (
              <Link
                key={team.id}
                className="ops-panel block p-5"
                to={`/teams/${team.id}`}
              >
                <p className="text-2xl font-black">{team.name}</p>
                <p className="mt-2 text-base font-bold text-textSecondary">
                  {team.memberCount} members · {team.scoreFet} FET
                </p>
              </Link>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<Users size={30} />}
            title="No teams yet"
            message="Teams will appear once guests join a venue game session."
          />
        )}
      </SectionCard>
    </OperationalPage>
  );
}

export function TeamDetailPage() {
  const { venue } = useVenue();
  const { teamId } = useParams();
  const teams = useAsyncData<VenueGameTeam[]>(
    () => (venue?.id ? fetchVenueGameTeams(venue.id) : Promise.resolve([])),
    [venue?.id],
    [],
  );
  const team = teams.data.find((item) => item.id === teamId);

  return (
    <OperationalPage
      eyebrow="Teams"
      title={team?.name ?? "Team detail"}
      description="Inspect one team, its linked game session, members, eligibility, score contributions, invite QR, and audit activity."
      icon={<Users size={26} />}
      status="scheduled"
      primaryAction={{ label: "Back to Teams", to: "/teams" }}
      secondaryAction={{ label: "Open Participants", to: "/participants" }}
      metrics={[
        {
          label: "Team",
          value: team ? shortId(team.id) : "None",
          detail: "Loaded from venue game team.",
        },
        {
          label: "Members",
          value: String(team?.memberCount ?? 0),
          detail: "6-digit user IDs only.",
        },
        {
          label: "Score",
          value: `${team?.scoreFet ?? 0} FET`,
          detail: "Validated answer or bingo claim records.",
        },
        {
          label: "Invite",
          value: team?.inviteCode ?? "Pending",
          detail: "QR source code.",
        },
      ]}
      rule
    >
      {teams.loading && <InlineLoading />}
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1fr_420px]">
        <SectionCard title="Members">
          <EmptyState
            icon={<ListChecks size={30} />}
            title="Member detail requires live roster expansion"
            message="The team card is linked; member-level eligibility appears in Participants."
          />
        </SectionCard>
        <SectionCard title="Invite and audit">
          <div className="space-y-4">
            <div className="ops-panel flex items-center justify-between gap-4 p-5">
              <div>
                <p className="text-xl font-black">Team invite QR</p>
                <p className="mt-1 text-sm font-bold text-textSecondary">
                  {team?.inviteCode ?? "Generated from live invite code."}
                </p>
              </div>
              <QrCode size={34} />
            </div>
            <AuditWarning>
              Member changes and moderation actions are permission-gated and
              logged.
            </AuditWarning>
          </div>
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

export function ParticipantsPage() {
  const { venue } = useVenue();
  const teams = useAsyncData<VenueGameTeam[]>(
    () => (venue?.id ? fetchVenueGameTeams(venue.id) : Promise.resolve([])),
    [venue?.id],
    [],
  );

  return (
    <OperationalPage
      eyebrow="Participants"
      title="Players and participants"
      description="Venue-scoped participant operations across pools, games, teams, order eligibility, pending FET, settled FET, and activity timeline."
      icon={<ListChecks size={26} />}
      status="scheduled"
      primaryAction={{ label: "Back to Overview", to: "/overview" }}
      secondaryAction={{ label: "Open Orders", to: "/orders" }}
      metrics={[
        {
          label: "Teams",
          value: String(teams.data.length),
          detail: "Current venue game teams.",
        },
        {
          label: "Filters",
          value: "Eligibility",
          detail: "Eligible, Order Required, Ineligible, Settled.",
        },
        {
          label: "Orders",
          value: "Linked",
          detail: "Qualifying orders are venue-specific.",
        },
        {
          label: "FET state",
          value: "Auditable",
          detail: "Pending and settled amounts trace to ledger.",
        },
      ]}
      rule
    >
      <SectionCard title="Participant table">
        <div className="mb-5 flex flex-wrap gap-3">
          {(
            ["eligible", "order_required", "ineligible", "settled"] as const
          ).map((state) => (
            <EligibilityBadge key={state} state={state} />
          ))}
        </div>
        {teams.data.length ? (
          <div className="space-y-3">
            {teams.data.map((team) => (
              <div
                key={team.id}
                className="rounded-2xl border border-border bg-surface2 p-4"
              >
                <p className="text-xl font-black">{team.name}</p>
                <p className="mt-1 text-base font-bold text-textSecondary">
                  {team.memberCount} members · {team.scoreFet} FET team score
                </p>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<Users size={30} />}
            title="No participants loaded"
            message="Participants appear after guests join a venue pool, game, or team."
          />
        )}
      </SectionCard>
    </OperationalPage>
  );
}

export function ScreenControlPage() {
  const { venue } = useVenue();
  const state = useAsyncData<VenueScreenState | null>(
    () => (venue?.id ? fetchVenueScreenState(venue.id) : Promise.resolve(null)),
    [venue?.id],
    null,
  );
  const displayUrl = safeHref(venue?.id ? tvDisplayUrl(venue.id) : null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busyMode, setBusyMode] = useState<VenueScreenMode | "reset" | null>(
    null,
  );

  async function push(mode: VenueScreenMode) {
    if (!venue?.id) return;
    setBusyMode(mode);
    setNotice(null);
    try {
      await setVenueScreenState({
        venueId: venue.id,
        mode,
        payload: { source: "venue_dashboard" },
      });
      setNotice(`${readableStatus(mode)} pushed to screen.`);
      state.refresh();
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Could not update screen.",
      );
    } finally {
      setBusyMode(null);
    }
  }

  return (
    <OperationalPage
      eyebrow="Screen"
      title="TV and live screen control"
      description="Manage the venue-linked TV display with QR joins, pool displays, game lobby, live questions, leaderboards, winners, promos, and reset controls."
      icon={<MonitorPlay size={26} />}
      status={state.data ? "live" : "disconnected"}
      primaryAction={{
        label: "Open Screen Settings",
        to: "/settings/screen",
      }}
      secondaryAction={{ label: "Open Games", to: "/games" }}
      metrics={[
        {
          label: "Connection",
          value: state.data ? "Connected" : "Pair required",
          detail: "Screen state belongs to this venue.",
        },
        {
          label: "Current mode",
          value: state.data ? readableStatus(state.data.mode) : "None",
          detail: "Live screen mode.",
        },
        {
          label: "QR",
          value: "Visible",
          detail: "Large enough for bar TV use.",
        },
        {
          label: "Data leakage",
          value: "Blocked",
          detail: "No cross-venue screen data.",
        },
      ]}
    >
      <Notice
        message={state.error ?? notice}
        tone={state.error || notice?.includes("Could") ? "danger" : "success"}
      />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <SectionCard
          title="Display modes"
          detail="Choose what the connected TV should show."
        >
          <div className="mb-5 rounded-2xl border border-primary/20 bg-primary/10 p-4">
            <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
              Standalone TV PWA
            </p>
            <p className="mt-2 text-base font-bold leading-7 text-text">
              Open the separate display app on the venue TV. It reads this venue
              screen state and refreshes through realtime.
            </p>
            {displayUrl ? (
              <a
                className="btn btn-primary mt-4 w-full"
                href={displayUrl}
                target="_blank"
                rel="noreferrer"
              >
                <MonitorPlay size={16} />
                Open TV Display
              </a>
            ) : (
              <button
                className="btn btn-primary mt-4 w-full"
                type="button"
                disabled
              >
                <MonitorPlay size={16} />
                Open TV Display
              </button>
            )}
          </div>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
            {screenModes.map(({ label, mode }) => (
              <button
                key={mode}
                className="btn btn-secondary justify-between"
                type="button"
                disabled={!!busyMode}
                onClick={() => push(mode)}
              >
                {busyMode === mode ? (
                  <Loader2 className="animate-spin" size={16} />
                ) : (
                  <MonitorPlay size={16} />
                )}
                {label}
              </button>
            ))}
          </div>
          <button
            className="btn btn-primary mt-5 w-full"
            type="button"
            disabled={!!busyMode}
            onClick={() => push("welcome")}
          >
            Reset screen
            <RefreshCcw size={16} />
          </button>
        </SectionCard>
        <SectionCard
          title="TV preview"
          detail="A fixed 16:9 preview for venue screen operators."
        >
          <TvPreview mode={state.data?.mode ?? "qr"} />
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

function TvPreview({ mode }: { mode: VenueScreenMode }) {
  return (
    <div className="aspect-video overflow-hidden rounded-3xl border border-border bg-[#050507] p-6 shadow-2xl shadow-black/30">
      <div className="flex h-full flex-col justify-between">
        <div className="flex items-center justify-between gap-4">
          <StatusChip status="live" label={readableStatus(mode)} />
          <QrCode size={42} />
        </div>
        <div>
          <p className="text-5xl font-black tracking-tight">
            {mode === "winners"
              ? "Winner reveal"
              : mode === "pool"
                ? "Prediction pool"
                : "Join the game"}
          </p>
          <p className="mt-4 max-w-2xl text-2xl font-black text-textSecondary">
            Join a team, order from the app, and unlock FET eligibility.
          </p>
        </div>
        <div className="flex items-center justify-between gap-4">
          <p className="text-xl font-black text-primary">
            FET rewards require a qualifying order
          </p>
          <MonitorPlay size={34} />
        </div>
      </div>
    </div>
  );
}

export function WalletPage() {
  const { venue } = useVenue();
  const wallet = useAsyncData<VenueFetWallet | null>(
    () => (venue?.id ? fetchVenueFetWallet(venue.id) : Promise.resolve(null)),
    [venue?.id],
    null,
  );
  const ledger = useAsyncData<VenueFetLedgerEntry[]>(
    () => (venue?.id ? fetchVenueFetLedger(venue.id, 5) : Promise.resolve([])),
    [venue?.id],
    [],
  );

  return (
    <OperationalPage
      eyebrow="FET wallet"
      title="Venue FET wallet"
      description="Review the bar wallet, buy requests, pool stakes, game reward reservations, pending settlements, distributed FET, and transaction history."
      icon={<Wallet size={26} />}
      status="scheduled"
      primaryAction={{ label: "Buy FET", to: "/wallet/buy" }}
      secondaryAction={{ label: "View Ledger", to: "/wallet/ledger" }}
    >
      <WalletMetrics wallet={wallet.data} />
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1fr_1fr]">
        <SectionCard title="Wallet safety model">
          <div className="space-y-4">
            {[
              "No wallet balance update without a ledger row",
              "No negative balances",
              "No direct UI mutation of FET balances",
              "All settlement payouts are transactional",
            ].map((rule) => (
              <div key={rule} className="ops-panel flex items-center gap-3 p-4">
                <CheckCircle2 className="text-success" size={20} />
                <p className="text-base font-black">{rule}</p>
              </div>
            ))}
          </div>
        </SectionCard>
        <SectionCard title="Recent ledger">
          {ledger.data.length ? (
            <LedgerRows rows={ledger.data} />
          ) : (
            <EmptyState
              icon={<ClipboardList size={30} />}
              title="No ledger rows loaded"
              message="Ledger rows appear after wallet activity."
            />
          )}
        </SectionCard>
      </div>
    </OperationalPage>
  );
}

export function BuyFetPage() {
  const { venue } = useVenue();
  const [amount, setAmount] = useState("1000");
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!venue?.id) return;
    setSaving(true);
    setNotice(null);
    try {
      await requestVenueFetTopUp(
        venue.id,
        Math.max(1, Number(amount) || 1),
        note,
      );
      setNotice("Top-up request submitted and pending platform confirmation.");
    } catch (err) {
      setNotice(
        err instanceof Error ? err.message : "Could not submit top-up request.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <OperationalPage
      eyebrow="FET wallet"
      title="Buy FET"
      description="Create a venue top-up request using platform payment instructions or an invoice request. No direct payment API integration is added for MVP."
      icon={<Coins size={26} />}
      status="draft"
      primaryAction={{ label: "Back to Wallet", to: "/wallet" }}
      secondaryAction={{ label: "View Ledger", to: "/wallet/ledger" }}
      metrics={[
        {
          label: "Top-up status",
          value: "Pending",
          detail: "Awaiting platform confirmation.",
        },
        {
          label: "Actor",
          value: "Owner / manager",
          detail: "Permission-gated action.",
        },
        {
          label: "Ledger",
          value: "Required",
          detail: "Wallet credit happens with transaction row.",
        },
        {
          label: "Payment API",
          value: "None",
          detail: "Instruction-only MVP flow.",
        },
      ]}
    >
      <Notice
        message={notice}
        tone={notice?.includes("Could") ? "danger" : "success"}
      />
      <form
        className="grid grid-cols-1 gap-6 xl:grid-cols-[0.9fr_1.1fr]"
        onSubmit={handleSubmit}
      >
        <SectionCard title="Top-up request">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {[500, 1000, 2500, 5000].map((packageAmount) => (
              <button
                key={packageAmount}
                className="ops-panel p-5 text-left transition hover:bg-surface3"
                type="button"
                onClick={() => setAmount(String(packageAmount))}
              >
                <p className="text-3xl font-black">
                  {packageAmount.toLocaleString()} FET
                </p>
                <p className="mt-2 text-sm font-bold text-textSecondary">
                  Package option
                </p>
              </button>
            ))}
          </div>
          <input
            className="input mt-5"
            type="number"
            min={1}
            value={amount}
            onChange={(event) => setAmount(event.target.value)}
          />
        </SectionCard>
        <SectionCard title="Confirmation">
          <div className="space-y-4">
            <AuditWarning>
              Submitting creates a pending top-up request. Platform confirmation
              credits the wallet and writes the ledger row.
            </AuditWarning>
            <input
              className="input"
              value={note}
              onChange={(event) => setNote(event.target.value)}
              placeholder="Reference / note"
            />
            <button
              className="btn btn-primary w-full"
              type="submit"
              disabled={saving || !venue?.id}
            >
              {saving ? (
                <Loader2 className="animate-spin" size={16} />
              ) : (
                <Coins size={16} />
              )}
              Submit top-up request
            </button>
          </div>
        </SectionCard>
      </form>
    </OperationalPage>
  );
}

export function WalletLedgerPage() {
  const { venue } = useVenue();
  const ledger = useAsyncData<VenueFetLedgerEntry[]>(
    () =>
      venue?.id ? fetchVenueFetLedger(venue.id, 100) : Promise.resolve([]),
    [venue?.id],
    [],
  );

  return (
    <OperationalPage
      eyebrow="FET wallet"
      title="Wallet ledger"
      description="Auditable FET transaction history with transaction type, amount, direction, reference, date, actor, linked entity, and status."
      icon={<ClipboardList size={26} />}
      status="scheduled"
      primaryAction={{ label: "Back to Wallet", to: "/wallet" }}
      secondaryAction={{ label: "Buy FET", to: "/wallet/buy" }}
      metrics={[
        {
          label: "Entries",
          value: String(ledger.data.length),
          detail: "Never derived from UI-only state.",
        },
        {
          label: "Directions",
          value: "In / out",
          detail: "Credit, debit, reserve, release.",
        },
        {
          label: "References",
          value: "Required",
          detail: "Pool, game, order, top-up, settlement.",
        },
        {
          label: "Export",
          value: "Permissioned",
          detail: "Owner/manager only.",
        },
      ]}
    >
      {ledger.loading && <InlineLoading />}
      <SectionCard title="Transactions">
        {ledger.data.length ? (
          <LedgerRows rows={ledger.data} />
        ) : (
          <EmptyState
            icon={<ClipboardList size={30} />}
            title="No wallet transactions loaded"
            message="Ledger rows will show type, amount, direction, reference, date, actor, linked entity, and status."
          />
        )}
      </SectionCard>
    </OperationalPage>
  );
}

export function NotificationsPage() {
  return (
    <OperationalPage
      eyebrow="Notifications"
      title="Venue notification center"
      description="Operational alerts for payment submissions, eligibility changes, wallet balance, game sessions, prediction pools, TV screen status, and system events."
      icon={<BellRing size={26} />}
      status="scheduled"
      primaryAction={{ label: "Back to Overview", to: "/overview" }}
      secondaryAction={{ label: "Open Orders", to: "/orders" }}
      metrics={[
        {
          label: "Payment alerts",
          value: "Actionable",
          detail: "Submitted, disputed, partially paid.",
        },
        {
          label: "Eligibility alerts",
          value: "Visible",
          detail: "Joined users needing orders.",
        },
        {
          label: "Wallet alerts",
          value: "Critical",
          detail: "Low balance before pools/games.",
        },
        {
          label: "Screen alerts",
          value: "Operational",
          detail: "Disconnected or stale TV display.",
        },
      ]}
      rule
    >
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        {[
          [
            "Payments",
            "Payment submitted, partially paid, disputed, and manual confirmation reminders link to order detail.",
          ],
          [
            "Eligibility",
            "Joined users who still need a qualifying order remain visible before settlement.",
          ],
          [
            "Screen and wallet",
            "Low wallet balance and disconnected TV warnings link to the correct module.",
          ],
        ].map(([title, detail]) => (
          <SectionCard key={title} title={title}>
            <p className="text-base font-semibold leading-7 text-textSecondary">
              {detail}
            </p>
          </SectionCard>
        ))}
      </div>
    </OperationalPage>
  );
}

export function StaffPermissionsPage() {
  const rows = [
    ["Buy FET", "Owner, Manager", "Cashier, Waiter, Host"],
    ["Create pool", "Owner, Manager", "Cashier, Waiter, Host"],
    ["Stake FET", "Owner, Manager", "Cashier, Waiter, Host"],
    ["Settle pool", "Owner, Manager", "Cashier, Waiter, Host"],
    ["Mark paid", "Owner, Manager, Cashier", "Waiter, Host"],
    ["End game", "Owner, Manager, Host", "Cashier, Waiter"],
    ["Edit menu", "Owner, Manager", "Cashier, Waiter, Host"],
  ];

  return (
    <OperationalPage
      eyebrow="Settings"
      title="Staff permissions"
      description="Permission-friendly control surface for owner, manager, cashier, waiter, and game host responsibilities."
      icon={<ShieldCheck size={26} />}
      status="scheduled"
      primaryAction={{ label: "Back to Settings", to: "/settings" }}
      secondaryAction={{ label: "Payment Settings", to: "/settings/payments" }}
      metrics={[
        {
          label: "Roles",
          value: "5",
          detail: "Owner, manager, cashier, waiter, host.",
        },
        {
          label: "High-impact actions",
          value: "Locked",
          detail: "FET, settlement, paid status.",
        },
        {
          label: "Audit",
          value: "Required",
          detail: "Permission changes and staff actions.",
        },
        {
          label: "Source of truth",
          value: "RLS",
          detail: "UI mirrors backend policies.",
        },
      ]}
    >
      <SectionCard
        title="Permission matrix"
        detail="Visible locks make restricted actions clear without weakening backend policies."
      >
        <div className="space-y-3">
          {rows.map(([action, allowed, locked]) => (
            <div
              key={action}
              className="grid grid-cols-1 gap-3 rounded-2xl border border-border bg-surface2 p-4 md:grid-cols-[220px_1fr_1fr]"
            >
              <p className="text-lg font-black">{action}</p>
              <div className="flex items-center gap-2 text-success">
                <CheckCircle2 size={18} />
                <p className="text-sm font-black">{allowed}</p>
              </div>
              <div className="flex items-center gap-2 text-warning">
                <LockKeyhole size={18} />
                <p className="text-sm font-black">{locked}</p>
              </div>
            </div>
          ))}
        </div>
      </SectionCard>
    </OperationalPage>
  );
}

export function SettingsSubsectionPage() {
  const { pathname } = useLocation();
  const section = pathname.includes("/payments")
    ? "payments"
    : pathname.includes("/screen")
      ? "screen"
      : "profile";
  const copy = {
    profile: {
      title: "Venue profile",
      description:
        "Manage venue identity, address, contact details, opening status, image assets, and operating context.",
      cards: [
        [
          "Venue identity",
          "Name, address, contact, logo, cover image, venue type, and public profile details.",
        ],
        [
          "Opening hours",
          "Daily open windows, temporary closure, live/open status, and holiday overrides.",
        ],
        [
          "Operational defaults",
          "Default currency, service model, table/reference behavior, and staff notes.",
        ],
      ],
    },
    payments: {
      title: "Payment settings",
      description:
        "Maintain external payment instructions and manual confirmation rules. No payment API integration is added for MVP.",
      cards: [
        [
          "MoMo USSD",
          "Rwanda order payment instructions, reference copy, and staff verification guidance.",
        ],
        [
          "Revolut link",
          "Malta/Europe payment link, fallback instruction, and reference note behavior.",
        ],
        [
          "Manual audit",
          "Staff confirmation, amount received, method, reference, note, and payment timeline requirements.",
        ],
      ],
    },
    screen: {
      title: "Screen settings",
      description:
        "Configure display pairing, default mode, idle behavior, promo strip, QR visibility, and reset behavior.",
      cards: [
        [
          "Pairing",
          "Connected screen indicator, pairing code, last heartbeat, and reset controls.",
        ],
        [
          "Default display",
          "Venue welcome, QR join, menu promo, pool display, game lobby, leaderboard, or winner mode.",
        ],
        [
          "Promo strip",
          "Sponsor/promo strip toggle and FET eligibility reminder for TV displays.",
        ],
      ],
    },
  }[section];

  return (
    <OperationalPage
      eyebrow="Settings"
      title={copy.title}
      description={copy.description}
      icon={<Settings size={26} />}
      status="scheduled"
      primaryAction={{ label: "Back to Settings", to: "/settings" }}
      secondaryAction={
        section === "screen"
          ? { label: "Open Screen Control", to: "/screen" }
          : undefined
      }
      metrics={[
        {
          label: "Venue scoped",
          value: "Yes",
          detail: "Settings apply only to the selected venue.",
        },
        {
          label: "Audit",
          value: "Required",
          detail: "Payment and permission changes are logged.",
        },
        {
          label: "MVP payments",
          value: "External",
          detail: "MoMo USSD and Revolut link guidance.",
        },
        {
          label: "Staff clarity",
          value: "High",
          detail: "Large readable operational controls.",
        },
      ]}
    >
      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        {copy.cards.map(([title, detail]) => (
          <SectionCard key={title} title={title}>
            <p className="text-base font-semibold leading-7 text-textSecondary">
              {detail}
            </p>
          </SectionCard>
        ))}
      </div>
    </OperationalPage>
  );
}
