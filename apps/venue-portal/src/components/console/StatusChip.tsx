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
        'inline-flex items-center rounded-full border px-3 py-1 text-[11px] font-black uppercase tracking-widest',
        toneClass[tone ?? statusTone(status)],
      )}
    >
      {label ?? readableStatus(status)}
    </span>
  );
}
