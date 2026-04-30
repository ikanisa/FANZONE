import { useEffect, useState } from 'react';
import { Trophy, UserPlus } from 'lucide-react';
import type { LeaderboardEntry } from '../types';
import { api } from '../services/api';

export default function Leaderboard() {
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);

  useEffect(() => {
    let active = true;
    api.getLeaderboard(16).then((rows) => {
      if (active) setEntries(rows);
    });
    return () => {
      active = false;
    };
  }, []);

  const podium = entries.slice(0, 3);
  const others = entries.slice(3, 8);
  const viewerRank = entries.findIndex((entry) => entry.displayName === 'You');

  return (
    <div className="min-h-screen bg-bg pb-24">
      <header className="pt-6 pb-4 px-5 border-b border-border bg-surface2 lg:bg-transparent">
        <h1 className="font-display text-4xl text-text tracking-tight mb-4 flex items-center gap-2">
          Leaderboard
        </h1>
        <div className="flex gap-2 overflow-x-auto pb-1 hide-scrollbar">
          <div className="px-3 py-1.5 rounded-full text-xs font-bold whitespace-nowrap bg-accent text-bg shadow-[0_0_10px_rgba(34,211,238,0.3)]">
            Global
          </div>
        </div>
      </header>

      <div className="flex justify-center items-end gap-2 p-6 bg-surface2 border-b border-border">
        {podium[1] ? (
          <PodiumItem rank={2} entry={podium[1]} height="h-28" />
        ) : (
          <PodiumSkeleton height="h-28" />
        )}
        {podium[0] ? (
          <PodiumItem rank={1} entry={podium[0]} height="h-36" />
        ) : (
          <PodiumSkeleton height="h-36" />
        )}
        {podium[2] ? (
          <PodiumItem rank={3} entry={podium[2]} height="h-24" />
        ) : (
          <PodiumSkeleton height="h-24" />
        )}
      </div>

      <div className="p-3 space-y-2">
        {others.length > 0 ? (
          others.map((entry, index) => (
            <LeaderboardRow
              key={entry.userId}
              rank={index + 4}
              name={entry.displayName}
              fet={`${entry.totalFet.toLocaleString()} FET`}
            />
          ))
        ) : (
          <div className="bg-surface2 p-4 rounded-xl border border-border text-sm text-muted">
            The public leaderboard will populate as predictions are settled.
          </div>
        )}
      </div>

      {entries.length > 0 && (
        <div className="fixed bottom-[70px] lg:bottom-4 left-3 right-3 bg-accent/10 border border-accent/20 rounded-2xl p-3 flex items-center justify-between backdrop-blur-lg z-40">
          <div className="flex items-center gap-3">
            <span className="font-mono text-accent font-bold w-6">
              #{viewerRank >= 0 ? viewerRank + 1 : entries.length}
            </span>
            <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center border border-accent/30 text-xs">
              👤
            </div>
            <div>
              <div className="text-sm font-bold text-text leading-tight">You</div>
              <div className="text-[10px] text-muted font-bold tracking-widest uppercase">
                Live rank snapshot
              </div>
            </div>
          </div>
          <div className="font-mono text-sm font-bold text-accent3">
            {entries[0]?.totalPoints.toLocaleString() ?? '0'} pts
          </div>
        </div>
      )}
    </div>
  );
}

function PodiumSkeleton({ height }: { height: string }) {
  return (
    <div className={`flex flex-col items-center gap-2 ${height}`}>
      <div className="w-6 h-6 rounded-full bg-surface3" />
      <div className={`w-16 ${height} bg-surface3 rounded-t-xl border-t border-x border-border`} />
      <div className="text-center space-y-1">
        <div className="w-12 h-3 rounded bg-surface3 mx-auto" />
        <div className="w-10 h-2 rounded bg-surface3 mx-auto" />
      </div>
    </div>
  );
}

function PodiumItem({
  rank,
  entry,
  height,
}: {
  rank: number;
  entry: LeaderboardEntry;
  height: string;
}) {
  return (
    <div className={`flex flex-col items-center gap-2 ${height}`}>
      <div className={rank === 1 ? 'text-accent' : rank === 2 ? 'text-muted' : 'text-accent3'}>
        <Trophy size={rank === 1 ? 32 : 24} />
      </div>
      <div
        className={`w-16 ${height} bg-surface3 rounded-t-xl border-t border-x border-border flex flex-col items-center justify-end p-2`}
      >
        <span className="font-mono text-xs font-bold text-text">#{rank}</span>
      </div>
      <div className="text-center">
        <div className="text-xs font-bold text-text leading-tight">
          {entry.displayName}
        </div>
        <div className="text-[10px] text-accent3 font-mono">
          {entry.totalPoints.toLocaleString()} pts
        </div>
      </div>
    </div>
  );
}


function LeaderboardRow({
  rank,
  name,
  fet,
}: {
  rank: number;
  name: string;
  fet: string;
}) {
  return (
    <div className="bg-surface2 p-3 rounded-xl border border-border flex items-center justify-between">
      <div className="flex items-center gap-3">
        <span className="font-mono text-muted text-xs font-bold w-5">{rank}</span>
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-xs border border-border">
          👤
        </div>
        <span className="text-sm font-bold text-text">{name}</span>
      </div>
      <div className="flex items-center gap-3">
        <span className="font-mono text-sm font-bold text-accent3">{fet}</span>
        <button className="w-8 h-8 rounded-full bg-surface3 border border-border text-muted hover:text-accent flex justify-center items-center transition-colors">
          <UserPlus size={14} />
        </button>
      </div>
    </div>
  );
}
