import { useMemo, useState, type FormEvent } from "react";
import { CheckCircle2, EyeOff, Plus, Search, Save } from "lucide-react";

import { PageHeader } from "../../components/layout/PageHeader";
import { DetailDrawer, DrawerField, DrawerSection } from "../../components/ui/DetailDrawer";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateViews";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { formatDateTime } from "../../lib/formatters";
import type { Match } from "../../types";
import {
  useCreateCuratedMatch,
  useCuratedMatches,
  useCurationMatchOptions,
  useSetCuratedMatchActive,
  useUpdateMatchState,
  type CuratedMatch,
  type MatchStateInput,
} from "./useMatchCuration";
import { buildCuratedMatchMetadata } from "../platform-control/controlCenter";

interface CurationFormState {
  match_id: string;
  country_code: string;
  venue_id: string;
  priority_score: string;
  curation_reason: string;
  starts_at: string;
  expires_at: string;
  tag_global: boolean;
  tag_country: boolean;
  tag_venue_relevant: boolean;
  tag_featured: boolean;
  tag_hidden: boolean;
}

const initialForm: CurationFormState = {
  match_id: "",
  country_code: "",
  venue_id: "",
  priority_score: "50",
  curation_reason: "",
  starts_at: "",
  expires_at: "",
  tag_global: true,
  tag_country: false,
  tag_venue_relevant: false,
  tag_featured: false,
  tag_hidden: false,
};

const initialMatchState: MatchStateInput["status"] = "live";

function fromDateTimeLocalValue(value: string) {
  if (!value.trim()) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function matchLabel(match: Match | undefined, fallbackId: string) {
  if (!match) return fallbackId;
  return `${match.home_team} vs ${match.away_team}`;
}

export function MatchCurationPage() {
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [optionSearch, setOptionSearch] = useState("");
  const [activeFilter, setActiveFilter] = useState("active");
  const [selected, setSelected] = useState<CuratedMatch | null>(null);
  const [form, setForm] = useState<CurationFormState>(initialForm);
  const [matchStatus, setMatchStatus] = useState<MatchStateInput["status"]>(initialMatchState);
  const [homeScore, setHomeScore] = useState("");
  const [awayScore, setAwayScore] = useState("");

  const {
    data: result,
    isLoading,
    error,
    refetch,
  } = useCuratedMatches({ page }, { search, active: activeFilter });
  const matchOptions = useCurationMatchOptions(optionSearch);
  const createCuratedMatch = useCreateCuratedMatch();
  const setActive = useSetCuratedMatchActive();
  const updateMatchState = useUpdateMatchState();

  const curatedMatches = result?.data ?? [];
  const matchById = useMemo(() => {
    const lookup = new Map<string, Match>();
    for (const match of matchOptions.data ?? []) {
      lookup.set(match.id, match);
    }
    return lookup;
  }, [matchOptions.data]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!form.match_id) return;

    await createCuratedMatch.mutateAsync({
      match_id: form.match_id,
      country_code: form.country_code,
      venue_id: form.venue_id,
      priority_score: Number(form.priority_score) || 0,
      curation_reason: form.curation_reason,
      starts_at: fromDateTimeLocalValue(form.starts_at),
      expires_at: fromDateTimeLocalValue(form.expires_at),
      is_active: !form.tag_hidden,
      metadata: buildCuratedMatchMetadata({
        global: form.tag_global,
        country: form.tag_country,
        venueRelevant: form.tag_venue_relevant,
        featured: form.tag_featured,
        hidden: form.tag_hidden,
      }),
    });

    setForm(initialForm);
  }

  async function handleMatchStateSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected) return;

    const parsedHome = homeScore.trim() === "" ? null : Number(homeScore);
    const parsedAway = awayScore.trim() === "" ? null : Number(awayScore);
    await updateMatchState.mutateAsync({
      match_id: selected.match_id,
      status: matchStatus,
      home_score: Number.isFinite(parsedHome) ? parsedHome : null,
      away_score: Number.isFinite(parsedAway) ? parsedAway : null,
    });
  }

  return (
    <div>
      <PageHeader
        title="Curated Matches"
        subtitle="Data-driven fixture curation for global, country, and venue pool discovery"
      />

      <form
        className="data-table-container"
        style={{ padding: 16, marginBottom: 16 }}
        onSubmit={handleSubmit}
      >
        <div className="flex items-start justify-between gap-3 mb-4">
          <div>
            <h2 className="font-semibold">Curate a Match</h2>
            <p className="text-sm text-muted">
              Select imported matches and make them eligible for pool discovery.
            </p>
          </div>
          <button
            className="btn btn-primary"
            disabled={createCuratedMatch.isPending || !form.match_id}
            type="submit"
          >
            <Plus size={16} /> Add Curation
          </button>
        </div>

        <div className="filter-bar">
          <div style={{ position: "relative", minWidth: 280, flex: 1 }}>
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
              placeholder="Find imported match..."
              value={optionSearch}
              onChange={(event) => setOptionSearch(event.target.value)}
            />
          </div>
          <select
            className="input select"
            value={form.match_id}
            onChange={(event) =>
              setForm((current) => ({ ...current, match_id: event.target.value }))
            }
            required
          >
            <option value="">Select match</option>
            {(matchOptions.data ?? []).map((match) => (
              <option key={match.id} value={match.id}>
                {match.home_team} vs {match.away_team} - {match.competition_name ?? match.competition_id}
              </option>
            ))}
          </select>
        </div>

        <div className="filter-bar">
          <input
            className="input"
            placeholder="Country code, optional"
            value={form.country_code}
            onChange={(event) =>
              setForm((current) => ({ ...current, country_code: event.target.value }))
            }
            maxLength={2}
            style={{ maxWidth: 180 }}
          />
          <input
            className="input"
            placeholder="Venue id, optional"
            value={form.venue_id}
            onChange={(event) =>
              setForm((current) => ({ ...current, venue_id: event.target.value }))
            }
            style={{ minWidth: 260 }}
          />
          <input
            className="input"
            type="number"
            min={0}
            max={1000}
            value={form.priority_score}
            onChange={(event) =>
              setForm((current) => ({ ...current, priority_score: event.target.value }))
            }
            style={{ maxWidth: 140 }}
          />
          <input
            className="input"
            placeholder="Commercial reason"
            value={form.curation_reason}
            onChange={(event) =>
              setForm((current) => ({ ...current, curation_reason: event.target.value }))
            }
            style={{ minWidth: 260, flex: 1 }}
          />
        </div>

        <div className="filter-bar">
          <label className="text-xs text-muted">
            Starts
            <input
              className="input"
              type="datetime-local"
              value={form.starts_at}
              onChange={(event) =>
                setForm((current) => ({ ...current, starts_at: event.target.value }))
              }
            />
          </label>
          <label className="text-xs text-muted">
            Expires
            <input
              className="input"
              type="datetime-local"
              value={form.expires_at}
              onChange={(event) =>
                setForm((current) => ({ ...current, expires_at: event.target.value }))
              }
            />
          </label>
        </div>

        <div className="filter-bar">
          {[
            ["tag_global", "Global"],
            ["tag_country", "Country"],
            ["tag_venue_relevant", "Venue-relevant"],
            ["tag_featured", "Featured"],
            ["tag_hidden", "Hidden"],
          ].map(([key, label]) => (
            <label key={key} className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={Boolean(form[key as keyof CurationFormState])}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    [key]: event.target.checked,
                  }))
                }
              />
              {label}
            </label>
          ))}
        </div>
      </form>

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
            placeholder="Search curated matches..."
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
              setPage(0);
            }}
          />
        </div>
        <select
          className="input select"
          style={{ maxWidth: 180 }}
          value={activeFilter}
          onChange={(event) => {
            setActiveFilter(event.target.value);
            setPage(0);
          }}
        >
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="all">All</option>
        </select>
      </div>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : curatedMatches.length === 0 ? (
        <EmptyState title="No curated matches found" />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Match</th>
                <th>Country</th>
                <th>Venue</th>
                <th>Priority</th>
                <th>Tags</th>
                <th>Status</th>
                <th>Window</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {curatedMatches.map((row) => (
                <tr
                  key={row.id}
                  className="cursor-pointer"
                  onClick={() => setSelected(row)}
                >
                  <td>
                    <div className="font-medium">
                      {matchLabel(matchById.get(row.match_id), row.match_id)}
                    </div>
                    <div className="text-xs text-muted mono">{row.match_id}</div>
                  </td>
                  <td>{row.country_code ?? "Global"}</td>
                  <td className="mono text-xs">{row.venue_id ?? "Platform"}</td>
                  <td>{row.priority_score}</td>
                  <td>
                    <div className="flex flex-wrap gap-1">
                      {Array.isArray(row.metadata?.tags) && row.metadata.tags.length > 0 ? (
                        row.metadata.tags.map((tag) => (
                          <span key={String(tag)} className="badge badge-neutral">{String(tag).replaceAll("_", " ")}</span>
                        ))
                      ) : (
                        <span className="text-xs text-muted">curated</span>
                      )}
                    </div>
                  </td>
                  <td>
                    <StatusBadge status={row.is_active ? "active" : "inactive"} />
                  </td>
                  <td className="text-xs text-muted">
                    {row.starts_at ? formatDateTime(row.starts_at) : "Now"}
                    {" -> "}
                    {row.expires_at ? formatDateTime(row.expires_at) : "No expiry"}
                  </td>
                  <td className="cell-actions">
                    <button
                      className="btn btn-ghost btn-sm"
                      disabled={setActive.isPending}
                      onClick={(event) => {
                        event.stopPropagation();
                        void setActive.mutateAsync({
                          id: row.id,
                          is_active: !row.is_active,
                        });
                      }}
                    >
                      {row.is_active ? <EyeOff size={14} /> : <CheckCircle2 size={14} />}
                      {row.is_active ? "Disable" : "Enable"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="pagination">
            <span>Showing {curatedMatches.length} of {result?.count ?? 0} curated matches</span>
            <div className="pagination-controls">
              <button className="pagination-btn" disabled={page === 0} onClick={() => setPage((value) => value - 1)}>←</button>
              <button className="pagination-btn active">{page + 1}</button>
              <button
                className="pagination-btn"
                disabled={curatedMatches.length < (result?.pageSize ?? 25)}
                onClick={() => setPage((value) => value + 1)}
              >
                →
              </button>
            </div>
          </div>
        </div>
      )}

      <DetailDrawer
        open={!!selected}
        title="Curated Match"
        subtitle={selected?.id}
        onClose={() => setSelected(null)}
      >
        {selected && (
          <>
            <DrawerSection title="Discovery">
              <DrawerField label="Match" value={matchLabel(matchById.get(selected.match_id), selected.match_id)} />
              <DrawerField label="Country" value={selected.country_code ?? "Global"} />
              <DrawerField label="Venue" value={selected.venue_id ?? "Platform"} />
              <DrawerField label="Priority" value={selected.priority_score} />
              <DrawerField label="Status" value={<StatusBadge status={selected.is_active ? "active" : "inactive"} />} />
            </DrawerSection>
            <DrawerSection title="Window">
              <DrawerField label="Starts" value={selected.starts_at ? formatDateTime(selected.starts_at) : "Now"} />
              <DrawerField label="Expires" value={selected.expires_at ? formatDateTime(selected.expires_at) : "No expiry"} />
              <DrawerField label="Reason" value={selected.reason ?? "—"} />
            </DrawerSection>
            <DrawerSection title="Match State">
              <form className="space-y-3" onSubmit={handleMatchStateSubmit}>
                <select
                  className="input select"
                  value={matchStatus}
                  onChange={(event) => setMatchStatus(event.target.value as MatchStateInput["status"])}
                >
                  <option value="scheduled">Scheduled</option>
                  <option value="live">Live</option>
                  <option value="final">Final</option>
                  <option value="cancelled">Cancelled</option>
                  <option value="postponed">Postponed</option>
                </select>
                <div className="grid grid-cols-2 gap-2">
                  <input
                    className="input"
                    type="number"
                    min={0}
                    placeholder="Home score"
                    value={homeScore}
                    onChange={(event) => setHomeScore(event.target.value)}
                  />
                  <input
                    className="input"
                    type="number"
                    min={0}
                    placeholder="Away score"
                    value={awayScore}
                    onChange={(event) => setAwayScore(event.target.value)}
                  />
                </div>
                <button
                  className="btn btn-primary"
                  type="submit"
                  disabled={updateMatchState.isPending || (matchStatus === "final" && (homeScore.trim() === "" || awayScore.trim() === ""))}
                >
                  <Save size={16} /> Update Match
                </button>
              </form>
            </DrawerSection>
          </>
        )}
      </DetailDrawer>
    </div>
  );
}
