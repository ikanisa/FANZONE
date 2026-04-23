import { useEffect, useMemo, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import {
  Calendar,
  ChevronRight as ChevronRightIcon,
  Globe,
  Trophy,
  Star,
  ChevronDown,
  Compass,
  Target,
} from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { Card } from "./ui/Card";
import { TeamLogo } from "./ui/TeamLogo";
import { useAppStore } from "../store/useAppStore";
import { api } from "../services/api";
import type { Competition, Match } from "../types";

function toDateKey(date: Date) {
  return date.toISOString().slice(0, 10);
}

function buildDateRail() {
  const start = new Date();
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(start);
    date.setDate(start.getDate() + index);
    return {
      id: toDateKey(date),
      day: date
        .toLocaleDateString(undefined, { weekday: "short" })
        .toUpperCase(),
      date: date
        .toLocaleDateString(undefined, {
          day: "2-digit",
          month: "short",
        })
        .toUpperCase(),
    };
  });
  return days;
}

export default function Fixtures() {
  const [activeTab, setActiveTab] = useState<"matches" | "competitions">(
    "matches",
  );

  return (
    <div className="min-h-screen bg-bg pb-32 transition-colors duration-300">
      <div className="px-4 pt-5 pb-3 flex items-center justify-between">
        <h1 className="font-display text-4xl text-text tracking-tight">
          Fixtures
        </h1>

        <div className="flex gap-1.5 bg-surface2 p-1 rounded-full border border-border">
          <button
            onClick={() => setActiveTab("matches")}
            className={`p-2 rounded-full transition-all flex items-center justify-center ${
              activeTab === "matches"
                ? "bg-accent text-bg shadow-sm"
                : "text-muted hover:text-text"
            }`}
          >
            <Calendar size={16} />
          </button>
          <button
            onClick={() => setActiveTab("competitions")}
            className={`p-2 rounded-full transition-all flex items-center justify-center ${
              activeTab === "competitions"
                ? "bg-[var(--accent2)] text-bg shadow-sm"
                : "text-muted hover:text-text"
            }`}
          >
            <Compass size={16} />
          </button>
        </div>
      </div>

      {activeTab === "matches" && <MatchesView />}
      {activeTab === "competitions" && <CompetitionsView />}
    </div>
  );
}

function CompetitionsView() {
  const navigate = useNavigate();
  const favoriteTeams = useAppStore((state) => state.favoriteTeams);
  const [showOthers, setShowOthers] = useState(false);
  const [competitions, setCompetitions] = useState<Competition[]>([]);

  useEffect(() => {
    let active = true;
    api.getCompetitions().then((rows) => {
      if (active) setCompetitions(rows);
    });
    return () => {
      active = false;
    };
  }, []);

  const featured = competitions.filter((competition) => competition.isFeatured);
  const rankedDomestic = [...competitions]
    .filter((competition) => !competition.isInternational)
    .sort((left, right) => {
      const leftRank = left.catalogRank ?? Number.MAX_SAFE_INTEGER;
      const rightRank = right.catalogRank ?? Number.MAX_SAFE_INTEGER;
      if (leftRank != rightRank) return leftRank - rightRank;
      if (left.futureMatchCount != right.futureMatchCount) {
        return right.futureMatchCount - left.futureMatchCount;
      }
      return left.name.localeCompare(right.name);
    });
  const topLeagues = (
    rankedDomestic.length > 0 ? rankedDomestic : featured
  ).slice(0, 5);
  const majorCompetitions = competitions
    .filter(
      (competition) =>
        competition.isInternational ||
        competition.competitionType?.toLowerCase() === "national",
    )
    .slice(0, 4);
  const otherLeagues = competitions
    .filter(
      (competition) =>
        !topLeagues.some((top) => top.id === competition.id) &&
        !majorCompetitions.some((major) => major.id === competition.id),
    )
    .slice(0, 6);

  return (
    <div className="p-4 space-y-6">
      <section>
        <div className="flex items-center gap-2 mb-2 px-1">
          <Star size={14} className="text-accent3" />
          <h2 className="font-sans font-bold text-sm text-text">For You</h2>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {(featured.slice(0, 1).length > 0
            ? featured.slice(0, 1)
            : competitions.slice(0, 1)
          ).map((competition) => (
            <Card
              key={competition.id}
              className="hover:border-accent/30 cursor-pointer group flex flex-col items-center justify-center p-3 text-center gap-1.5 border-border shadow-none"
              onClick={() => navigate(`/league/${competition.id}`)}
            >
              <div className="w-8 h-8 rounded-full bg-surface2 border border-border flex justify-center items-center text-sm shadow-inner">
                {competition.isInternational ? "🌍" : "🏆"}
              </div>
              <div>
                <h3 className="font-bold text-[10px] text-text group-hover:text-accent transition-colors leading-tight">
                  {competition.shortName || competition.name}
                </h3>
              </div>
            </Card>
          ))}

          {favoriteTeams.slice(0, 2).map((team) => (
            <Card
              key={team}
              className="hover:border-accent/30 cursor-pointer group flex flex-col items-center justify-center p-3 text-center gap-1.5 border-border shadow-none"
              onClick={() => navigate("/profile")}
            >
              <div className="w-8 h-8 rounded-full bg-surface2 border border-border flex justify-center items-center overflow-hidden">
                <TeamLogo teamName={team} size={20} />
              </div>
              <div>
                <h3 className="font-bold text-[10px] text-text group-hover:text-accent transition-colors leading-tight truncate px-1 max-w-full block">
                  {team}
                </h3>
              </div>
            </Card>
          ))}
        </div>
      </section>

      <section>
        <div className="flex items-center gap-2 mb-2 px-1">
          <Globe size={14} className="text-accent" />
          <h2 className="font-sans font-bold text-sm text-text">Top Leagues</h2>
        </div>
        <div className="grid gap-1.5">
          {topLeagues.map((competition) => (
            <div
              key={competition.id}
              onClick={() => navigate(`/league/${competition.id}`)}
              className="bg-surface hover:bg-surface2 transition-all px-3 py-2.5 rounded-[14px] border border-border flex items-center justify-between cursor-pointer group"
            >
              <div className="flex items-center gap-3">
                <div className="text-base">
                  {competition.isInternational ? "🌍" : "🏆"}
                </div>
                <div className="font-bold text-text text-xs group-hover:text-accent transition-colors">
                  {competition.name}
                </div>
              </div>
              <ChevronRightIcon
                size={14}
                className="text-muted/50 group-hover:text-accent transition-colors"
              />
            </div>
          ))}

          {otherLeagues.length > 0 && (
            <div className="mt-1">
              <button
                onClick={() => setShowOthers(!showOthers)}
                className="w-full bg-surface2/50 hover:bg-surface2 transition-all py-2 rounded-[14px] border border-transparent hover:border-border flex items-center justify-center gap-2 text-muted hover:text-text font-bold text-[10px]"
              >
                <ChevronDown
                  size={12}
                  className={`transition-transform ${showOthers ? "rotate-180" : ""}`}
                />
                OTHER LEAGUES
              </button>
              <AnimatePresence>
                {showOthers && (
                  <motion.div
                    initial={{ height: 0, opacity: 0 }}
                    animate={{ height: "auto", opacity: 1 }}
                    exit={{ height: 0, opacity: 0 }}
                    className="overflow-hidden mt-1.5"
                  >
                    <div className="grid gap-3">
                      {otherLeagues.map((competition) => (
                        <div
                          key={competition.id}
                          onClick={() => navigate(`/league/${competition.id}`)}
                          className="bg-surface p-4 rounded-xl border border-border flex items-center gap-4 cursor-pointer hover:border-text transition-colors"
                        >
                          <div className="text-xl">
                            {competition.isInternational ? "🌍" : "⚽"}
                          </div>
                          <div>
                            <div className="font-bold text-text text-sm">
                              {competition.name}
                            </div>
                            <div className="text-xs text-muted">
                              {competition.country || "Global"}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          )}
        </div>
      </section>

      <section>
        <div className="flex items-center gap-2 mb-2 px-1">
          <Trophy size={14} className="text-[var(--accent2)]" />
          <h2 className="font-sans font-bold text-sm text-text">
            Major Tournaments
          </h2>
        </div>
        <div className="grid grid-cols-2 gap-2">
          {majorCompetitions.map((competition) => (
            <div
              key={competition.id}
              className="bg-surface hover:bg-surface2 transition-all p-3 rounded-[14px] border border-border cursor-pointer group flex flex-col gap-1.5"
              onClick={() => navigate(`/league/${competition.id}`)}
            >
              <div className="flex items-center justify-between">
                <div className="text-xl group-hover:scale-110 transition-transform">
                  {competition.competitionType === "cup" ? "🏆" : "🌎"}
                </div>
                <ChevronRightIcon
                  size={12}
                  className="text-muted/30 group-hover:text-accent transition-colors"
                />
              </div>
              <div>
                <h3 className="font-bold text-text text-[10px] leading-tight group-hover:text-accent transition-colors truncate">
                  {competition.name}
                </h3>
                <p className="text-[9px] text-muted truncate">
                  {competition.currentSeasonLabel || "Current season"}
                </p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}

function MatchesView() {
  const navigate = useNavigate();
  const [matches, setMatches] = useState<Match[]>([]);
  const [activeLeague, setActiveLeague] = useState("All");
  const dates = useMemo(() => buildDateRail(), []);
  const [activeDate, setActiveDate] = useState(
    dates[0]?.id ?? toDateKey(new Date()),
  );

  useEffect(() => {
    let active = true;
    const start = `${dates[0]?.id ?? toDateKey(new Date())}T00:00:00.000Z`;
    const end = `${dates[dates.length - 1]?.id ?? toDateKey(new Date())}T23:59:59.999Z`;

    api.getMatchesWindow(start, end).then((rows) => {
      if (active) setMatches(rows);
    });

    return () => {
      active = false;
    };
  }, [dates]);

  const leagueOptions = useMemo(() => {
    const labels = [
      ...new Set(
        matches.map((match) => match.competitionLabel).filter(Boolean),
      ),
    ];
    return ["All", ...labels];
  }, [matches]);

  const filteredMatches = matches.filter((match) => {
    const matchDateKey = match.date.slice(0, 10);
    const matchesDate = matchDateKey === activeDate;
    const matchesLeague =
      activeLeague === "All" || match.competitionLabel === activeLeague;
    return matchesDate && matchesLeague;
  });

  const activeDateLabel =
    dates.find((item) => item.id === activeDate)?.date ?? "";

  return (
    <>
      <header className="bg-bg/95 backdrop-blur-xl border-b border-border shadow-sm flex flex-col gap-2 pt-2 pb-1">
        <div className="flex items-center gap-2 px-4 w-full">
          <button className="shrink-0 w-11 h-11 rounded-full bg-surface2 flex items-center justify-center font-bold text-[10px] text-text hover:bg-surface3 transition-colors border border-border shadow-sm">
            LIVE
          </button>

          <div className="flex-1 flex gap-2 px-1 overflow-x-auto hide-scrollbar snap-x">
            {dates.map((date) => (
              <button
                key={date.id}
                onClick={() => setActiveDate(date.id)}
                className={`shrink-0 snap-center flex flex-col items-center justify-center px-4 py-2.5 rounded-xl transition-all ${
                  date.id === activeDate
                    ? "bg-surface2 text-text font-bold shadow-[0_4px_12px_rgba(0,0,0,0.1)] border border-border/50 scale-105"
                    : "text-muted hover:text-text bg-transparent"
                }`}
              >
                <span className="text-[11px] font-bold uppercase tracking-widest leading-none mb-1">
                  {date.day}
                </span>
                <span
                  className={`text-[10px] uppercase font-bold tracking-wider opacity-80 leading-none ${
                    date.id === activeDate ? "text-text" : "text-muted"
                  }`}
                >
                  {date.date}
                </span>
              </button>
            ))}
          </div>

          <button className="shrink-0 w-11 h-11 rounded-full bg-surface2 flex items-center justify-center text-muted hover:text-text hover:bg-surface3 transition-colors border border-border shadow-sm">
            <Calendar size={18} className="font-light" />
          </button>
        </div>

        <div className="flex gap-1.5 overflow-x-auto hide-scrollbar px-4 pb-2 pt-1 mt-1">
          {leagueOptions.map((league) => (
            <button
              key={league}
              onClick={() => setActiveLeague(league)}
              className={`px-3 py-1.5 rounded-full text-xs font-bold whitespace-nowrap transition-all ${
                activeLeague === league
                  ? "bg-text text-bg shadow-sm"
                  : "bg-surface2 border border-border text-muted hover:text-text"
              }`}
            >
              {league}
            </button>
          ))}
        </div>
      </header>

      <div className="p-4 space-y-6">
        {filteredMatches.length > 0 ? (
          <FixtureGroup
            date={`Selected: ${activeDateLabel}`}
            matches={filteredMatches}
          />
        ) : (
          <div className="text-center p-12 text-muted">
            <span className="text-2xl mb-4 block">⚽</span>
            <p className="font-bold text-sm">
              No matches found for this selection.
            </p>
          </div>
        )}
      </div>
    </>
  );
}

function FixtureGroup({ date, matches }: { date: string; matches: Match[] }) {
  return (
    <div>
      <h3 className="text-[10px] font-bold text-muted uppercase tracking-widest mb-2 px-1">
        {date}
      </h3>
      <div className="rounded-[20px] bg-surface flex flex-col divide-y divide-border/50 border border-border overflow-hidden shadow-sm">
        {matches.map((match) => (
          <FixtureItem key={match.id} match={match} />
        ))}
      </div>
    </div>
  );
}

function FixtureItem({ match }: { match: Match }) {
  const navigate = useNavigate();

  return (
    <div className="p-3.5 flex items-center justify-between group hover:bg-surface2 transition-colors gap-3">
      <Link
        to={`/match/${match.id}`}
        className="flex items-center gap-3 flex-1 min-w-0"
      >
        <div className="font-mono text-[10px] font-bold text-muted w-8 text-center shrink-0">
          {match.timeLabel}
        </div>

        <div className="flex-1 flex flex-col justify-center gap-2 min-w-0">
          <div className="flex items-center gap-2.5">
            <div className="w-5 h-5 rounded-full overflow-hidden bg-bg flex items-center justify-center shrink-0 border border-border/50 shadow-sm">
              <TeamLogo
                teamName={match.homeTeam}
                src={match.homeLogoUrl}
                size={20}
                className="w-full h-full object-contain"
              />
            </div>
            <span className="text-sm font-bold text-text group-hover:text-accent transition-all truncate leading-none">
              {match.homeTeam}
            </span>
          </div>
          <div className="flex items-center gap-2.5">
            <div className="w-5 h-5 rounded-full overflow-hidden bg-bg flex items-center justify-center shrink-0 border border-border/50 shadow-sm">
              <TeamLogo
                teamName={match.awayTeam}
                src={match.awayLogoUrl}
                size={20}
                className="w-full h-full object-contain"
              />
            </div>
            <span className="text-sm font-bold text-text group-hover:text-accent transition-all truncate leading-none">
              {match.awayTeam}
            </span>
          </div>
        </div>
      </Link>

      <div className="flex items-center gap-2 shrink-0 pr-1">
        <button
          onClick={(event) => {
            event.preventDefault();
            navigate(`/match/${match.id}`);
          }}
          className="w-10 h-10 rounded-full bg-[var(--accent2)]/10 text-[var(--accent2)] hover:bg-[var(--accent2)] hover:text-bg flex items-center justify-center transition-colors border border-[var(--accent2)]/20"
        >
          <Target size={18} />
        </button>
      </div>
    </div>
  );
}
