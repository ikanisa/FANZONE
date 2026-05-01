import { useState, type FormEvent } from "react";
import { CheckCircle2, Globe2, Landmark, Pencil, Power } from "lucide-react";

import { PageHeader } from "../../components/layout/PageHeader";
import { KpiCard } from "../../components/ui/KpiCard";
import { EmptyState, ErrorState, LoadingState } from "../../components/ui/StateViews";
import { StatusBadge } from "../../components/ui/StatusBadge";
import { useRpcMutation, useSupabaseList } from "../../hooks/useSupabaseQuery";
import { formatDateTime } from "../../lib/formatters";
import { ROLLOUT_REGIONS, normalizeCountryIso } from "../platform-control/controlCenter";

interface CountryRow {
  id: string;
  name: string;
  iso_code: string;
  region: string;
  is_active: boolean;
  rollout_priority: number;
  created_at: string;
  updated_at: string;
}

interface CountryFormState {
  id: string | null;
  name: string;
  iso_code: string;
  region: string;
  rollout_priority: string;
  is_active: boolean;
}

const initialForm: CountryFormState = {
  id: null,
  name: "",
  iso_code: "",
  region: "africa",
  rollout_priority: "100",
  is_active: true,
};

function fromCountry(row: CountryRow): CountryFormState {
  return {
    id: row.id,
    name: row.name,
    iso_code: row.iso_code,
    region: row.region,
    rollout_priority: String(row.rollout_priority),
    is_active: row.is_active,
  };
}

export function CountriesPage() {
  const [form, setForm] = useState<CountryFormState>(initialForm);

  const {
    data: countries = [],
    isLoading,
    error,
    refetch,
  } = useSupabaseList<CountryRow>(["countries"], "countries", {
    order: { column: "rollout_priority", ascending: true },
  });

  const upsertCountry = useRpcMutation<{
    p_id: string | null;
    p_name: string;
    p_iso_code: string;
    p_region: string;
    p_is_active: boolean;
    p_rollout_priority: number;
  }>({
    fnName: "admin_upsert_country",
    invalidateKeys: [["countries"], ["dashboard-kpis"]],
    successMessage: "Country rollout settings saved.",
  });

  const setCountryActive = useRpcMutation<{
    p_country_id: string;
    p_is_active: boolean;
  }>({
    fnName: "admin_set_country_active",
    invalidateKeys: [["countries"], ["dashboard-kpis"]],
    successMessage: "Country status updated.",
  });

  const activeCount = countries.filter((country) => country.is_active).length;
  const regionCount = new Set(countries.map((country) => country.region)).size;
  const nextPriority = Math.min(
    ...countries.map((country) => country.rollout_priority),
    100,
  );

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    await upsertCountry.mutateAsync({
      p_id: form.id,
      p_name: form.name.trim(),
      p_iso_code: normalizeCountryIso(form.iso_code),
      p_region: form.region,
      p_is_active: form.is_active,
      p_rollout_priority: Number(form.rollout_priority) || 100,
    });

    setForm(initialForm);
  }

  return (
    <div>
      <PageHeader
        title="Countries"
        subtitle="Rollout markets for venue discovery, country pools, teams, and curated match visibility."
      />

      <div className="grid grid-4 gap-4 mb-6">
        <KpiCard label="Countries" value={countries.length} icon={<Globe2 size={18} />} />
        <KpiCard label="Active" value={activeCount} icon={<CheckCircle2 size={18} />} />
        <KpiCard label="Regions" value={regionCount} icon={<Landmark size={18} />} />
        <KpiCard label="Top Priority" value={nextPriority} icon={<Power size={18} />} />
      </div>

      <form className="data-table-container mb-4" style={{ padding: 16 }} onSubmit={handleSubmit}>
        <div className="flex items-center justify-between gap-3 mb-4">
          <div>
            <h2 className="font-semibold">{form.id ? "Edit Country" : "Add Country"}</h2>
            <p className="text-sm text-muted">Use only approved rollout regions. Priority 0 appears first.</p>
          </div>
          <button className="btn btn-primary" type="submit" disabled={upsertCountry.isPending}>
            {form.id ? "Save Country" : "Add Country"}
          </button>
        </div>
        <div className="filter-bar">
          <input
            className="input"
            placeholder="Country name"
            value={form.name}
            onChange={(event) => setForm((current) => ({ ...current, name: event.target.value }))}
            required
          />
          <input
            className="input"
            placeholder="ISO code"
            value={form.iso_code}
            onChange={(event) => setForm((current) => ({ ...current, iso_code: event.target.value.toUpperCase() }))}
            maxLength={2}
            required
            style={{ maxWidth: 120 }}
          />
          <select
            className="input select"
            value={form.region}
            onChange={(event) => setForm((current) => ({ ...current, region: event.target.value }))}
            style={{ maxWidth: 220 }}
          >
            {ROLLOUT_REGIONS.map((region) => (
              <option key={region.value} value={region.value}>{region.label}</option>
            ))}
          </select>
          <input
            className="input"
            type="number"
            min={0}
            value={form.rollout_priority}
            onChange={(event) => setForm((current) => ({ ...current, rollout_priority: event.target.value }))}
            style={{ maxWidth: 140 }}
          />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={form.is_active}
              onChange={(event) => setForm((current) => ({ ...current, is_active: event.target.checked }))}
            />
            Active
          </label>
          {form.id && (
            <button className="btn btn-secondary" type="button" onClick={() => setForm(initialForm)}>
              Clear
            </button>
          )}
        </div>
      </form>

      {isLoading ? (
        <LoadingState lines={6} />
      ) : error ? (
        <ErrorState onRetry={() => refetch()} />
      ) : countries.length === 0 ? (
        <EmptyState
          title="No countries configured"
          description="Add the first rollout market before approving venues or country pools."
        />
      ) : (
        <div className="data-table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Country</th>
                <th>ISO</th>
                <th>Region</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Updated</th>
                <th className="cell-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              {countries.map((country) => (
                <tr key={country.id}>
                  <td>
                    <div className="font-medium">{country.name}</div>
                    <div className="text-xs text-muted mono">{country.id}</div>
                  </td>
                  <td className="mono text-xs">{country.iso_code}</td>
                  <td>{country.region.replaceAll("_", " ")}</td>
                  <td>{country.rollout_priority}</td>
                  <td><StatusBadge status={country.is_active ? "active" : "inactive"} /></td>
                  <td className="text-xs text-muted">{formatDateTime(country.updated_at)}</td>
                  <td className="cell-actions">
                    <button className="btn btn-ghost btn-sm" type="button" onClick={() => setForm(fromCountry(country))}>
                      <Pencil size={14} /> Edit
                    </button>
                    <button
                      className="btn btn-ghost btn-sm"
                      type="button"
                      disabled={setCountryActive.isPending}
                      onClick={() =>
                        setCountryActive.mutateAsync({
                          p_country_id: country.id,
                          p_is_active: !country.is_active,
                        })
                      }
                    >
                      {country.is_active ? "Deactivate" : "Activate"}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
