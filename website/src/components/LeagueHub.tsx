import { useEffect, useMemo, useState } from 'react';
import { ChevronLeft, Shield, Plus, Radar, ChevronRight } from 'lucide-react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useScrollDirection } from '../hooks/useScrollDirection';
import { MatchCard } from './ui/MatchCard';
import { Badge } from './ui/Badge';
import { Card } from './ui/Card';
import { TeamLogo } from './ui/TeamLogo';
import { api } from '../services/api';
import type { Competition, Match, Team } from '../types';

export default function LeagueHub() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const scrollDirection = useScrollDirection();
  const [competition, setCompetition] = useState<Competition | null>(null);
  const [matches, setMatches] = useState<Match[]>([]);
  const [teams, setTeams] = useState<Team[]>([]);

  useEffect(() => {
    if (!id) return;
    let active = true;

    Promise.all([
      api.getCompetitionById(id),
      api.getCompetitionMatches(id, 12),
      api.getCompetitionTeams(id),
    ]).then(([competitionRow, matchRows, teamRows]) => {
      if (!active) return;
      setCompetition(competitionRow);
      setMatches(matchRows);
      setTeams(teamRows);
    });

    return () => {
      active = false;
    };
  }, [id]);

  const liveMatches = matches.filter((match) => match.isLive).slice(0, 4);
  const spotlightMatches = matches
    .filter((match) => match.isLive || match.isUpcoming)
    .slice(0, 4);
  const topTeams = [...teams]
    .sort((left, right) => right.fanCount - left.fanCount)
    .slice(0, 4);
  const competitionName = competition?.name || 'Competition';

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      <header
        className={`sticky z-30 transition-all duration-300 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between ${
          scrollDirection === 'down' ? '-top-20 lg:top-0' : 'top-0'
        }`}
      >
        <Link to="/fixtures" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-xs font-bold text-muted uppercase tracking-widest">
            {competition?.isInternational ? 'Tournament Action' : 'League Action'}
          </div>
          <div className="text-sm font-bold text-text truncate max-w-[200px]">
            {competitionName}
          </div>
        </div>
        <div className="w-6" />
      </header>

      <div className="bg-surface2 p-6 border-b border-border relative overflow-hidden">
        <div className="absolute top-0 right-0 w-64 h-64 bg-accent/10 rounded-full blur-3xl translate-x-1/3 -translate-y-1/3 pointer-events-none" />

        <div className="flex items-center gap-4 mb-4 relative z-10">
          <div className="w-16 h-16 bg-surface rounded-full flex items-center justify-center text-3xl shadow-inner border border-border shrink-0">
            {competition?.isInternational ? '🌍' : '🏆'}
          </div>
          <div>
            <h1 className="font-display text-2xl md:text-3xl text-text tracking-tight mb-1">
              {competitionName}
            </h1>
            <div className="flex gap-3 text-[10px] font-bold text-muted uppercase tracking-widest">
              <span className="flex items-center gap-1">
                Live Now <span className="text-accent">{liveMatches.length}</span>
              </span>
              <span>{competition?.currentSeasonLabel || 'Current season'}</span>
            </div>
          </div>
        </div>

        <div className="flex gap-3 mt-6 relative z-10">
          <button
            onClick={() => navigate('/predict')}
            className="flex-1 bg-accent text-surface font-bold py-3 rounded-xl flex justify-center items-center gap-2 hover:opacity-90 active:scale-[0.98] transition-all shadow-[0_0_15px_rgba(34,211,238,0.3)] text-xs"
          >
            <Plus size={16} /> MAKE PICKS
          </button>
          <button
            onClick={() => navigate('/leaderboard')}
            className="flex-1 bg-surface border border-border text-text font-bold py-3 rounded-xl flex justify-center items-center gap-2 hover:bg-surface3 active:scale-[0.98] transition-all text-xs"
          >
            <Shield size={16} /> LEADERBOARD
          </button>
        </div>
      </div>

      <div className="p-4 space-y-8">
        <section>
          <div className="flex items-center justify-between mb-3 px-2">
            <h2 className="font-sans font-bold text-lg text-text flex items-center gap-2">
              Action Center <Badge variant="danger" pulse>{liveMatches.length}</Badge>
            </h2>
            <Link to="/fixtures" className="text-xs font-bold text-accent">
              SEE ALL
            </Link>
          </div>
          <div className="grid gap-3">
            {spotlightMatches.map((match) => (
              <MatchCard
                key={match.id}
                matchId={match.id}
                home={match.homeTeam}
                away={match.awayTeam}
                homeLogoUrl={match.homeLogoUrl}
                awayLogoUrl={match.awayLogoUrl}
                live={match.isLive}
                score={match.score ?? undefined}
                time={match.timeLabel}
                league={competitionName}
              />
            ))}
            {spotlightMatches.length === 0 && (
              <Card className="p-6 border-border text-sm text-muted">
                No live or upcoming fixtures are available in this competition window yet.
              </Card>
            )}
          </div>
        </section>

        <section>
          <div className="flex items-center justify-between mb-3 px-2">
            <h2 className="font-sans font-bold text-lg text-text flex items-center gap-2">
              <Radar size={20} className="text-[var(--accent2)]" /> Feature Radar
            </h2>
            <Link to="/predict" className="text-xs font-bold text-accent">
              OPEN PREDICT
            </Link>
          </div>
          <div className="grid gap-3">
            {matches
              .filter((match) => match.isUpcoming)
              .slice(0, 2)
              .map((match) => (
                <Card key={match.id} className="p-0 border-border overflow-hidden">
                  <div className="p-4 flex items-start justify-between">
                    <div>
                      <Badge variant="ghost" className="mb-2">
                        {match.matchdayOrRound || match.stage || 'Upcoming'}
                      </Badge>
                      <h3 className="font-bold text-text text-lg leading-tight mb-1">
                        {match.homeTeam} vs {match.awayTeam}
                      </h3>
                      <p className="text-xs text-muted mb-3 flex items-center gap-4">
                        <span>{match.dateLabel}</span>
                        <span>{match.kickoffLabel}</span>
                      </p>
                    </div>
                    <div className="text-right">
                      <span className="text-[10px] font-bold text-muted uppercase block">
                        Pick Window
                      </span>
                      <span className="text-xl text-[var(--accent2)] tracking-tight font-bold">
                        OPEN
                      </span>
                    </div>
                  </div>
                  <div className="bg-surface2 px-4 py-3 flex gap-2">
                    <button
                      onClick={() => navigate(`/match/${match.id}`)}
                      className="w-full bg-surface border border-border rounded-lg py-2 text-sm font-bold text-text hover:bg-text hover:text-bg transition-colors"
                    >
                      VIEW MATCH
                    </button>
                    <button
                      onClick={() => navigate(`/match/${match.id}`)}
                      className="px-4 bg-[var(--accent2)] text-bg rounded-lg font-bold flex items-center justify-center hover:opacity-90"
                    >
                      PREDICT
                    </button>
                  </div>
                </Card>
              ))}
          </div>
        </section>

        <section>
          <div className="flex items-center justify-between mb-3 px-2">
            <h2 className="font-sans font-bold text-lg text-text flex items-center gap-2">
              Teams To Watch
            </h2>
          </div>
          <div className="bg-surface rounded-2xl border border-border overflow-hidden divide-y divide-border/50">
            {topTeams.map((team) => (
              <div
                key={team.id}
                className="p-4 flex items-center justify-between hover:bg-surface2 transition-colors cursor-pointer"
                onClick={() => navigate(`/team/${team.id}`)}
              >
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center text-xl overflow-hidden">
                    <TeamLogo
                      teamName={team.name}
                      src={team.crestUrl || team.logoUrl}
                      size={32}
                    />
                  </div>
                  <div>
                    <h4 className="font-bold text-text text-sm">{team.name}</h4>
                    <span className="text-xs text-muted">
                      {team.fanCount.toLocaleString()} Fans
                    </span>
                  </div>
                </div>
                <ChevronRight size={18} className="text-muted" />
              </div>
            ))}
            {topTeams.length === 0 && (
              <div className="p-4 text-sm text-muted">
                Team cards will appear once the competition catalog is hydrated.
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
