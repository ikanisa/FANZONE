// FANZONE Admin — Enter Match Result Modal
import { useState } from 'react';
import { Target } from 'lucide-react';

interface EnterResultModalProps {
  open: boolean;
  matchId: string;
  matchLabel: string;
  onConfirm: (homeScore: number, awayScore: number) => void;
  onCancel: () => void;
  isPending: boolean;
  settlePoolsAfter?: boolean;
}

export function EnterResultModal({ open, matchId, matchLabel, onConfirm, onCancel, isPending, settlePoolsAfter }: EnterResultModalProps) {
  const [homeScore, setHomeScore] = useState('');
  const [awayScore, setAwayScore] = useState('');

  if (!open) return null;

  const isValid = homeScore !== '' && awayScore !== '' &&
    !isNaN(Number(homeScore)) && !isNaN(Number(awayScore)) &&
    Number(homeScore) >= 0 && Number(awayScore) >= 0;

  return (
    <div className="modal-overlay" onClick={onCancel}>
      <div className="modal-panel" onClick={e => e.stopPropagation()} style={{ maxWidth: 420 }}>
        <div className="flex items-center gap-3 mb-5">
          <div style={{ color: 'var(--fz-primary)', flexShrink: 0 }}>
            <Target size={24} />
          </div>
          <div>
            <h3 className="text-md font-semibold">Enter Match Result</h3>
            <p className="text-xs text-muted mt-1">{matchId} — {matchLabel}</p>
          </div>
        </div>

        <p className="text-sm text-muted mb-4">
          Enter the official full-time score for this fixture.
          {settlePoolsAfter && ' All associated prediction pools will be settled automatically after confirming.'}
        </p>

        <div className="flex gap-4 mb-6">
          <div className="field-group" style={{ flex: 1 }}>
            <label className="label">Home Score</label>
            <input
              type="number"
              className="input"
              placeholder="0"
              min={0}
              value={homeScore}
              onChange={e => setHomeScore(e.target.value)}
              autoFocus
              style={{ textAlign: 'center', fontSize: 'var(--fz-text-2xl)', fontWeight: 700 }}
            />
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-end', paddingBottom: 8 }}>
            <span className="text-lg text-muted font-semibold">—</span>
          </div>
          <div className="field-group" style={{ flex: 1 }}>
            <label className="label">Away Score</label>
            <input
              type="number"
              className="input"
              placeholder="0"
              min={0}
              value={awayScore}
              onChange={e => setAwayScore(e.target.value)}
              style={{ textAlign: 'center', fontSize: 'var(--fz-text-2xl)', fontWeight: 700 }}
            />
          </div>
        </div>

        <div className="flex justify-end gap-3">
          <button className="btn btn-secondary" onClick={onCancel} disabled={isPending}>Cancel</button>
          <button
            className="btn btn-primary"
            onClick={() => onConfirm(Number(homeScore), Number(awayScore))}
            disabled={!isValid || isPending}
          >
            {isPending ? 'Saving...' : settlePoolsAfter ? 'Save & Settle Pools' : 'Save Result'}
          </button>
        </div>
      </div>
    </div>
  );
}
