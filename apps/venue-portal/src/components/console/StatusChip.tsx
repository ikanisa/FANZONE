import { clsx } from 'clsx';
import { readableStatus, statusTone, toneClass, type StatusTone } from './status';

export function StatusChip({
  status,
  label,
  tone,
}: {
  status: string;
  label?: string;
  tone?: StatusTone;
}) {
  return (
    <span
      className={clsx(
        'inline-flex min-h-8 items-center rounded-full border px-3.5 py-1.5 text-[12px] font-black uppercase tracking-wide',
        toneClass[tone ?? statusTone(status)],
      )}
    >
      {label ?? readableStatus(status)}
    </span>
  );
}
