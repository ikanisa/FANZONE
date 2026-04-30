// FANZONE Admin — Formatting Utilities
import type { AdminRole } from '../config/constants';
import { ROLE_HIERARCHY } from '../config/constants';

export function formatNumber(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toLocaleString();
}

export function formatFET(amount: number): string {
  return `${formatNumber(amount)} FET`;
}

export function formatDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toLocaleDateString('en-MT', { day: 'numeric', month: 'short', year: 'numeric' });
}

export function formatDateTime(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  return d.toLocaleString('en-MT', {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

export function formatKickoffTime(
  date: string | Date,
  kickoffTime: string | null | undefined,
): string {
  const value = kickoffTime?.trim();
  if (!value) return '—';

  const match = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/.exec(value);
  if (!match) return value;

  const baseDate = typeof date === 'string' ? new Date(date) : date;
  if (Number.isNaN(baseDate.getTime())) return value;

  const hour = Number(match[1]);
  const minute = Number(match[2]);
  const second = Number(match[3] ?? '0');

  const kickoff = new Date(
    Date.UTC(
      baseDate.getUTCFullYear(),
      baseDate.getUTCMonth(),
      baseDate.getUTCDate(),
      hour,
      minute,
      second,
    ),
  );

  return kickoff.toLocaleTimeString('en-GB', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

export function formatRelativeTime(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const diff = Date.now() - d.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'Just now';
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return formatDate(d);
}

export function hasMinRole(userRole: AdminRole, minRole: AdminRole): boolean {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[minRole];
}

export function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1).replace(/_/g, ' ');
}

export function statusColor(status: string): string {
  const s = status.toLowerCase();
  if (['active', 'approved', 'fulfilled', 'completed', 'settled', 'published', 'sent', 'resolved'].includes(s)) return 'success';
  if (['pending', 'draft', 'open', 'scheduled', 'investigating', 'review'].includes(s)) return 'warning';
  if (['rejected', 'cancelled', 'suspended', 'failed', 'error', 'critical', 'escalated', 'disputed', 'archived'].includes(s)) return 'error';
  if (['live', 'locked'].includes(s)) return 'info';
  return 'neutral';
}
