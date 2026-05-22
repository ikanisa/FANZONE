import { type ReactNode } from "react";
import { Link } from "react-router-dom";
import {
  AlertTriangle,
  ArrowRight,
  Loader2,
  LockKeyhole,
  ShieldCheck,
} from "lucide-react";
import { StatusChip } from "../../components/console/StatusChip";
import { readableStatus } from "../../components/console/status";
import type {
  VenueFetLedgerEntry,
  VenueFetWallet,
} from "../../services/venueOperations";
import {
  eligibilityRule,
  formatDate,
  type Action,
  type Metric,
} from "./targetPageUtils";

export function Notice({
  message,
  tone = "neutral",
}: {
  message: string | null;
  tone?: "neutral" | "danger" | "success";
}) {
  if (!message) return null;
  const toneClass =
    tone === "danger"
      ? "border-danger/25 bg-danger/10 text-danger"
      : tone === "success"
        ? "border-success/25 bg-success/10 text-success"
        : "border-border bg-surface2 text-text";
  return (
    <div
      className={`rounded-2xl border px-5 py-4 text-sm font-black ${toneClass}`}
    >
      {message}
    </div>
  );
}

function ActionButton({
  action,
  primary = false,
}: {
  action: Action;
  primary?: boolean;
}) {
  const className = primary ? "btn btn-primary" : "btn btn-secondary";

  if (action.disabled || !action.to) {
    return (
      <button type="button" className={className} disabled>
        {action.label}
        <ArrowRight size={16} />
      </button>
    );
  }

  return (
    <Link className={className} to={action.to}>
      {action.label}
      <ArrowRight size={16} />
    </Link>
  );
}

export function OperationalPage({
  eyebrow,
  title,
  description,
  icon,
  status = "scheduled",
  primaryAction,
  secondaryAction,
  metrics,
  children,
  rule,
}: {
  eyebrow: string;
  title: string;
  description: string;
  icon: ReactNode;
  status?: string;
  primaryAction?: Action;
  secondaryAction?: Action;
  metrics?: Metric[];
  children: ReactNode;
  rule?: boolean;
}) {
  return (
    <div className="mx-auto max-w-7xl space-y-8">
      <section className="ops-card overflow-hidden">
        <div className="grid grid-cols-1 gap-8 p-7 md:p-8 lg:grid-cols-[1fr_360px]">
          <div>
            <div className="flex flex-wrap items-center gap-3">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-primaryText">
                {icon}
              </div>
              <div>
                <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
                  {eyebrow}
                </p>
                <StatusChip status={status} />
              </div>
            </div>
            <h1 className="mt-6 max-w-4xl text-4xl font-black tracking-tight md:text-5xl">
              {title}
            </h1>
            <p className="mt-4 max-w-3xl text-lg font-semibold leading-8 text-textSecondary">
              {description}
            </p>
            <div className="mt-7 flex flex-wrap gap-3">
              {primaryAction && <ActionButton action={primaryAction} primary />}
              {secondaryAction && <ActionButton action={secondaryAction} />}
            </div>
          </div>

          <div className="ops-panel flex flex-col justify-between gap-6 p-5">
            <div>
              <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
                Venue scope
              </p>
              <p className="mt-3 text-2xl font-black">Current venue only</p>
              <p className="mt-2 text-base font-semibold leading-7 text-textSecondary">
                This dashboard never creates global competition logic or
                cross-venue operations.
              </p>
            </div>
            <div className="rounded-2xl border border-success/20 bg-success/10 p-4 text-success">
              <div className="flex items-center gap-2 font-black">
                <ShieldCheck size={18} />
                Product rule locked
              </div>
              <p className="mt-2 text-sm font-bold leading-6 text-text">
                Data access and high-impact actions remain policy-backed and
                auditable.
              </p>
            </div>
          </div>
        </div>
      </section>

      {metrics && <MetricStrip metrics={metrics} />}

      {rule && <EligibilityRuleCard />}

      {children}
    </div>
  );
}

function MetricStrip({ metrics }: { metrics: Metric[] }) {
  return (
    <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
      {metrics.map((metric) => (
        <article key={metric.label} className="ops-card p-5">
          <p className="text-sm font-black uppercase tracking-wide text-textSecondary">
            {metric.label}
          </p>
          <p className="mt-3 text-3xl font-black tracking-tight">
            {metric.value}
          </p>
          {metric.detail && (
            <p className="mt-2 text-sm font-bold leading-6 text-textSecondary">
              {metric.detail}
            </p>
          )}
        </article>
      ))}
    </section>
  );
}

function EligibilityRuleCard() {
  return (
    <section className="ops-card border-warning/30 bg-warning/10 p-5 md:p-6">
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <p className="text-sm font-black uppercase tracking-wide text-warning">
            Eligibility rule
          </p>
          <p className="mt-2 text-lg font-black leading-8 text-text">
            {eligibilityRule}
          </p>
        </div>
        <LockKeyhole className="shrink-0 text-warning" size={30} />
      </div>
    </section>
  );
}

export function SectionCard({
  title,
  detail,
  children,
}: {
  title: string;
  detail?: string;
  children: ReactNode;
}) {
  return (
    <section className="ops-card p-6">
      <div className="mb-5">
        <h2 className="text-2xl font-black tracking-tight">{title}</h2>
        {detail && (
          <p className="mt-2 text-base font-semibold leading-7 text-textSecondary">
            {detail}
          </p>
        )}
      </div>
      {children}
    </section>
  );
}

export function AuditWarning({
  children = "This action will be logged.",
}: {
  children?: ReactNode;
}) {
  return (
    <div className="rounded-2xl border border-warning/25 bg-warning/10 p-4">
      <div className="flex items-start gap-3">
        <AlertTriangle className="mt-1 shrink-0 text-warning" size={20} />
        <p className="text-base font-black leading-7">{children}</p>
      </div>
    </div>
  );
}

export function InlineLoading({
  label = "Loading live data",
}: {
  label?: string;
}) {
  return (
    <div className="ops-card flex items-center justify-center gap-3 p-8 text-textSecondary">
      <Loader2 className="animate-spin" size={22} />
      <span className="text-base font-black">{label}</span>
    </div>
  );
}

export function WalletMetrics({ wallet }: { wallet: VenueFetWallet | null }) {
  const safeWallet = wallet ?? {
    availableBalanceFet: 0,
    stakedBalanceFet: 0,
    pendingBalanceFet: 0,
  };

  return (
    <MetricStrip
      metrics={[
        {
          label: "Available",
          value: `${safeWallet.availableBalanceFet.toLocaleString()} FET`,
          detail: "Spendable venue balance.",
        },
        {
          label: "Staked",
          value: `${safeWallet.stakedBalanceFet.toLocaleString()} FET`,
          detail: "Locked in pools or games.",
        },
        {
          label: "Pending",
          value: `${safeWallet.pendingBalanceFet.toLocaleString()} FET`,
          detail: "Top-ups or settlement holds.",
        },
        {
          label: "Reward scope",
          value: "Venue-only",
          detail: "FET stays inside loyalty and coupon flows.",
        },
      ]}
    />
  );
}

export function LedgerRows({ rows }: { rows: VenueFetLedgerEntry[] }) {
  return (
    <div className="space-y-3">
      {rows.map((row) => (
        <div
          key={row.id}
          className="grid grid-cols-1 gap-3 rounded-2xl border border-border bg-surface2 p-4 md:grid-cols-[1fr_140px_140px]"
        >
          <div>
            <p className="text-lg font-black">
              {row.title || readableStatus(row.transactionType)}
            </p>
            <p className="mt-1 text-sm font-bold text-textSecondary">
              {row.referenceType ?? "wallet"} · {formatDate(row.createdAt)}
            </p>
          </div>
          <p
            className={`text-2xl font-black ${row.direction === "credit" ? "text-success" : "text-warning"}`}
          >
            {row.direction === "credit" ? "+" : "-"}
            {row.amountFet.toLocaleString()} FET
          </p>
          <StatusChip status={row.status} />
        </div>
      ))}
    </div>
  );
}
