import { useEffect, useMemo, useState } from 'react';
import { ChevronLeft, Calendar, ShieldCheck } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import { TeamLogo } from './ui/TeamLogo';
import { api } from '../services/api';
import type { Match, Team } from '../types';

export default function TeamProfile() {
  const { id } = useParams();
  const [team, setTeam] = useState<Team | null>(null);
  const [relatedMatches, setRelatedMatches] = useState<Match[]>([]);

  useEffect(() => {
    if (!id) return;
    let active = true;

    api.getTeamByIdOrSlug(id).then(async (teamRow) => {
      if (!active) return;
      setTeam(teamRow);
      if (!teamRow) return;
      const matches = await api.getTeamMatches(teamRow.id, 8);
      if (active) setRelatedMatches(matches);
    });

    return () => {
      active = false;
    };
  }, [id]);

  const leagueLabel =
    team?.leagueName ||
    (team?.competitionIds.length ? team.competitionIds[0] : null) ||
    relatedMatches[0]?.competitionLabel ||
    'N/A';
  const liveReadyLabel = relatedMatches.some((match) => match.isLive) ? 'Live' : 'Ready';

  return (
    <div className="min-h-screen bg-bg pb-24">
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between">
        <Link to="/fixtures" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">
            Team Overview
          </div>
        </div>
        <div className="w-6" />
      </header>

      <div className="relative h-44 bg-gradient-to-br from-surface2 to-surface border-b border-border overflow-hidden">
        <div className="absolute inset-0 opacity-20 bg-[radial-gradient(circle_at_top_right,_rgba(34,211,238,0.35),_transparent_45%),radial-gradient(circle_at_bottom_left,_rgba(255,127,80,0.24),_transparent_42%)]" />
        <div className="absolute -bottom-8 left-6 w-24 h-24 rounded-full bg-surface border-4 border-surface2 flex items-center justify-center shadow-xl z-10 overflow-hidden p-3">
          <TeamLogo
            teamName={team?.name || 'Team'}
            src={team?.crestUrl || team?.logoUrl}
            size={64}
          />
        </div>
      </div>

      <div className="pt-12 px-6 pb-6 bg-surface2 border-b border-border">
        <h1 className="font-display text-3xl text-text tracking-widest mb-1">
          {team?.name || 'Team'}
        </h1>
        <p className="text-xs text-muted mb-6">
          Lean team profile synced to the fixtures and predictions stack.
        </p>

        <div className="grid grid-cols-3 gap-3 mb-6">
          <StatCard label="Fixtures" value={`${relatedMatches.length}`} />
          <StatCard label="League" value={leagueLabel} compact />
          <StatCard label="Status" value={liveReadyLabel} compact />
        </div>

        <div className="bg-surface3 border border-border rounded-xl p-4 flex items-start gap-3">
          <div className="w-10 h-10 rounded-full bg-success/10 border border-success/20 flex items-center justify-center text-success shrink-0">
            <ShieldCheck size={18} />
          </div>
          <div>
            <div className="text-[9px] font-bold tracking-widest uppercase text-text mb-1">
              Lean Model
            </div>
            <div className="text-[12px] text-muted leading-relaxed">
              This page now focuses on team identity and fixtures only. Legacy
              community and contribution layers are no longer part of the
              retained flow.
            </div>
          </div>
        </div>
      </div>

      <div className="p-6 space-y-6">
        <section>
          <div className="flex items-center gap-2 mb-3">
            <Calendar size={14} className="text-accent" />
            <h3 className="font-display text-xl text-text tracking-widest">
              RECENT FIXTURES
            </h3>
          </div>
          <div className="space-y-3">
            {relatedMatches.length > 0 ? (
              relatedMatches.slice(0, 4).map((match) => (
                <Link
                  key={match.id}
                  to={`/match/${match.id}`}
                  className="block bg-surface2 border border-border rounded-2xl p-4 hover:border-accent/40 transition-colors"
                >
                  <div className="flex items-center justify-between gap-3">
                    <div>
                      <div className="text-xs font-bold text-text">{match.homeTeam}</div>
                      <div className="text-xs font-bold text-text">{match.awayTeam}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-[10px] font-bold uppercase tracking-widest text-muted">
                        {match.status}
                      </div>
                      <div className="text-sm font-mono text-text">
                        {match.score || match.timeLabel || 'Scheduled'}
                      </div>
                    </div>
                  </div>
                </Link>
              ))
            ) : (
              <div className="bg-surface2 border border-border rounded-2xl p-5 text-sm text-muted">
                This team does not have fixtures in the current lean dataset yet.
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  compact = false,
}: {
  label: string;
  value: string;
  compact?: boolean;
}) {
  return (
    <div className="bg-surface3 rounded-xl p-3 text-center">
      <div className={`font-mono font-bold text-text ${compact ? 'text-sm' : 'text-xl'}`}>
        {value}
      </div>
      <div className="text-[9px] text-muted uppercase tracking-widest mt-1">
        {label}
      </div>
    </div>
  );
}
