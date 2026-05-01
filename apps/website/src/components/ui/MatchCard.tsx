import { motion } from "motion/react";
import { Link, useNavigate } from "react-router-dom";
import { Card } from "./Card";
import { Badge } from "./Badge";
import { TeamLogo } from "./TeamLogo";
import { ChevronRight, Trophy } from "lucide-react";

interface MatchCardProps {
  matchId: string;
  home: string;
  away: string;
  homeLogoUrl?: string | null;
  awayLogoUrl?: string | null;
  live?: boolean;
  score?: string;
  time: string;
  league?: string;
}

export function MatchCard({
  matchId,
  home,
  away,
  homeLogoUrl,
  awayLogoUrl,
  live = false,
  score,
  time,
  league = "Competition",
}: MatchCardProps) {
  const matchName = `${home} vs ${away}`;
  const navigate = useNavigate();

  return (
    <Card
      className={`p-5 hover:border-accent/40 group transition-all relative overflow-hidden ${live ? "border-danger/30 shadow-[0_0_24px_rgba(239,68,68,0.08)]" : ""}`}
    >
      {/* Live background glow */}
      {live && (
        <div className="absolute top-0 right-1/2 w-48 h-48 bg-danger/5 rounded-full blur-3xl translate-x-1/2 pointer-events-none" />
      )}

      <div className="flex justify-between items-center mb-5 relative z-10">
        <Badge
          variant="ghost"
          className="font-bold tracking-widest text-[9px] py-1"
        >
          {league} · {time}
        </Badge>
        {live && (
          <Badge variant="danger" pulse className="px-1.5 py-0.5 text-[9px]">
            LIVE
          </Badge>
        )}
      </div>

      <Link to={`/match/${matchId}`} className="block relative z-10">
        <div className="flex justify-between items-center mb-5">
          <div className="flex flex-col items-center gap-3 w-[35%]">
            <div className="w-16 h-16 rounded-2xl overflow-hidden bg-surface2 flex items-center justify-center border border-border group-hover:border-accent/30 transition-colors shadow-inner">
              <TeamLogo
                teamName={home}
                src={homeLogoUrl}
                size={42}
                className="w-full h-full object-contain p-1"
              />
            </div>
            <span className="font-black text-sm text-center leading-tight truncate px-1 w-full">
              {home}
            </span>
          </div>
          <div className="w-[30%] flex justify-center">
            <div
              className={`font-mono text-3xl font-bold tracking-tight ${live ? "text-danger [text-shadow:0_0_15px_rgba(239,68,68,0.2)]" : "text-text"}`}
            >
              {live ? score : "VS"}
            </div>
          </div>
          <div className="flex flex-col items-center gap-3 w-[35%]">
            <div className="w-16 h-16 rounded-2xl overflow-hidden bg-surface2 flex items-center justify-center border border-border group-hover:border-accent/30 transition-colors shadow-inner">
              <TeamLogo
                teamName={away}
                src={awayLogoUrl}
                size={42}
                className="w-full h-full object-contain p-1"
              />
            </div>
            <span className="font-black text-sm text-center leading-tight truncate px-1 w-full">
              {away}
            </span>
          </div>
        </div>
      </Link>

      <div className="grid grid-cols-2 gap-3 relative z-10">
        <button
          onClick={(e) => {
            e.preventDefault();
            navigate(`/match/${matchId}`);
          }}
          className={`h-12 rounded-xl font-black text-xs uppercase tracking-widest flex items-center justify-center gap-2 transition-all ${
            live
              ? "bg-danger text-bg hover:opacity-90 shadow-[0_0_15px_rgba(239,68,68,0.3)]"
              : "bg-[var(--accent2)] text-bg hover:opacity-90"
          }`}
        >
          <Trophy size={16} /> JOIN POOL
        </button>
        <button
          onClick={(e) => {
            e.preventDefault();
            navigate(`/match/${matchId}`);
          }}
          className="bg-surface border border-accent/20 text-accent hover:bg-accent hover:text-bg h-12 rounded-xl font-black text-xs uppercase tracking-widest flex items-center justify-center gap-2 transition-all shadow-sm"
        >
          <ChevronRight size={16} /> DETAILS
        </button>
      </div>
    </Card>
  );
}
