import { useEffect, useMemo, useState } from 'react';
import {
  Bell,
  ChevronLeft,
  Loader2,
  MessageSquare,
  Plus,
  Share2,
  Sparkles,
} from 'lucide-react';
import { Link, useParams } from 'react-router-dom';
import PredictionOptionsSheet from './PredictionOptionsSheet';
import { StatsPanel } from './ui/StatsPanel';
import { TeamLogo } from './ui/TeamLogo';
import { api } from '../services/api';
import { isPlatformFeatureVisible } from '../platform/access';
import { usePlatformBootstrap } from '../platform/bootstrap';
import type {
  Match,
  PredictionConsensus,
  PredictionEngineOutput,
  StandingRow,
  TeamFormFeature,
  UserPrediction,
} from '../types';

type PredictionTab = 'Predict' | 'Insights' | 'Stats' | 'Comments';

interface PredictionDraft {
  resultCode: string | null;
  over25: boolean | null;
  btts: boolean | null;
  homeGoals: number | null;
  awayGoals: number | null;
}

function emptyDraft(): PredictionDraft {
  return {
    resultCode: null,
    over25: null,
    btts: null,
    homeGoals: null,
    awayGoals: null,
  };
}

function computeResultCode(homeGoals: number, awayGoals: number): string {
  if (homeGoals > awayGoals) return 'H';
  if (homeGoals < awayGoals) return 'A';
  return 'D';
}

function toPercent(value: number | null | undefined): number {
  if (value == null) return 0;
  if (value <= 1) return Math.round(value * 100);
  return Math.round(value);
}

function getStandingForTeam(
  standings: StandingRow[],
  teamId: string | null | undefined,
  teamName: string,
) {
  return (
    standings.find((row) => row.teamId === teamId) ??
    standings.find((row) => row.teamName.toLowerCase() === teamName.toLowerCase()) ??
    null
  );
}

function getFormForTeam(
  formRows: TeamFormFeature[],
  teamId: string | null | undefined,
  fallbackIndex: number,
) {
  return formRows.find((row) => row.teamId === teamId) ?? formRows[fallbackIndex] ?? null;
}

function formatOutcomeLabel(resultCode: string | null, match: Match | null): string {
  if (!resultCode || !match) return 'Not selected';
  if (resultCode === 'H') return `${match.homeTeam} win`;
  if (resultCode === 'A') return `${match.awayTeam} win`;
  return 'Draw';
}

function formatPredictionSummary(prediction: UserPrediction | null, match: Match | null) {
  if (!prediction || !match) return null;

  const scoreline =
    prediction.predictedHomeGoals != null && prediction.predictedAwayGoals != null
      ? `${prediction.predictedHomeGoals}-${prediction.predictedAwayGoals}`
      : 'No exact score';

  return {
    result: formatOutcomeLabel(prediction.predictedResultCode ?? null, match),
    goals: prediction.predictedOver25 == null ? 'Not set' : prediction.predictedOver25 ? 'Over 2.5' : 'Under 2.5',
    btts: prediction.predictedBtts == null ? 'Not set' : prediction.predictedBtts ? 'BTTS Yes' : 'BTTS No',
    scoreline,
  };
}

export default function MatchDetail() {
  const { id } = useParams();
  const { bootstrap } = usePlatformBootstrap();
  const [activeTab, setActiveTab] = useState<PredictionTab>('Predict');
  const [isPredictionOptionsOpen, setIsPredictionOptionsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [saveFeedback, setSaveFeedback] = useState<{ tone: 'success' | 'error'; message: string } | null>(null);
  const [match, setMatch] = useState<Match | null>(null);
  const [engine, setEngine] = useState<PredictionEngineOutput | null>(null);
  const [consensus, setConsensus] = useState<PredictionConsensus | null>(null);
  const [formRows, setFormRows] = useState<TeamFormFeature[]>([]);
  const [standings, setStandings] = useState<StandingRow[]>([]);
  const [prediction, setPrediction] = useState<UserPrediction | null>(null);
  const [draft, setDraft] = useState<PredictionDraft>(emptyDraft());

  useEffect(() => {
    let active = true;

    async function loadMatch() {
      if (!id) {
        setLoadError('Match not found.');
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setLoadError(null);
      setSaveFeedback(null);

      const nextMatch = await api.getMatchDetail(id);
      if (!active) return;

      if (!nextMatch) {
        setMatch(null);
        setLoadError('This match could not be loaded.');
        setIsLoading(false);
        return;
      }

      const [nextEngine, nextFormRows, nextConsensus, nextPrediction, allStandings] =
        await Promise.all([
          api.getPredictionEngineOutput(id),
          api.getMatchFormFeatures(id),
          api.getMatchPredictionConsensus(id),
          api.getMyPredictionForMatch(id),
          api.getCompetitionStandings(nextMatch.competitionId, nextMatch.seasonLabel ?? undefined),
        ]);

      if (!active) return;

      const latestSnapshotDate = allStandings[0]?.snapshotDate ?? null;
      setMatch(nextMatch);
      setEngine(nextEngine);
      setConsensus(nextConsensus);
      setFormRows(nextFormRows);
      setPrediction(nextPrediction);
      setStandings(
        latestSnapshotDate
          ? allStandings.filter((row) => row.snapshotDate === latestSnapshotDate)
          : allStandings,
      );
      setDraft(
        nextPrediction
          ? {
              resultCode: nextPrediction.predictedResultCode ?? null,
              over25: nextPrediction.predictedOver25 ?? null,
              btts: nextPrediction.predictedBtts ?? null,
              homeGoals: nextPrediction.predictedHomeGoals ?? null,
              awayGoals: nextPrediction.predictedAwayGoals ?? null,
            }
          : emptyDraft(),
      );
      setIsLoading(false);
    }

    void loadMatch();

    return () => {
      active = false;
    };
  }, [id]);

  const homeStanding = useMemo(
    () => getStandingForTeam(standings, match?.homeTeamId, match?.homeTeam ?? ''),
    [match?.homeTeam, match?.homeTeamId, standings],
  );
  const awayStanding = useMemo(
    () => getStandingForTeam(standings, match?.awayTeamId, match?.awayTeam ?? ''),
    [match?.awayTeam, match?.awayTeamId, standings],
  );
  const homeForm = useMemo(
    () => getFormForTeam(formRows, match?.homeTeamId, 0),
    [formRows, match?.homeTeamId],
  );
  const awayForm = useMemo(
    () => getFormForTeam(formRows, match?.awayTeamId, 1),
    [formRows, match?.awayTeamId],
  );
  const predictionSummary = useMemo(
    () => formatPredictionSummary(prediction, match),
    [match, prediction],
  );
  const canPredict = isPlatformFeatureVisible('predictions', { surface: 'action' });
  const showNotifications = isPlatformFeatureVisible('notifications', {
    surface: 'route',
  });
  const visibleTabs = useMemo(
    () =>
      (['Predict', 'Insights', 'Stats', 'Comments'] as PredictionTab[]).filter(
        (tab) => canPredict || tab !== 'Predict',
      ),
    [bootstrap, canPredict],
  );

  useEffect(() => {
    if (!canPredict && activeTab === 'Predict') {
      setActiveTab('Insights');
    }
  }, [activeTab, canPredict]);

  const handleSelectResult = (resultCode: string) => {
    setDraft((current) => {
      const scoreConflicts =
        current.homeGoals != null &&
        current.awayGoals != null &&
        computeResultCode(current.homeGoals, current.awayGoals) !== resultCode;

      return {
        ...current,
        resultCode,
        homeGoals: scoreConflicts ? null : current.homeGoals,
        awayGoals: scoreConflicts ? null : current.awayGoals,
      };
    });
  };

  const handleSelectScore = (homeGoals: number, awayGoals: number) => {
    setDraft((current) => ({
      ...current,
      homeGoals,
      awayGoals,
      resultCode: computeResultCode(homeGoals, awayGoals),
      over25: homeGoals + awayGoals > 2,
      btts: homeGoals > 0 && awayGoals > 0,
    }));
  };

  const handleShare = async () => {
    if (!match) return;

    const shareText = `${match.homeTeam} vs ${match.awayTeam} · ${match.kickoffLabel}`;

    try {
      if (navigator.share) {
        await navigator.share({
          title: `${match.homeTeam} vs ${match.awayTeam}`,
          text: shareText,
          url: window.location.href,
        });
        return;
      }

      await navigator.clipboard.writeText(`${shareText} ${window.location.href}`);
      setSaveFeedback({ tone: 'success', message: 'Match link copied to clipboard.' });
    } catch (error) {
      setSaveFeedback({ tone: 'error', message: 'Sharing is not available on this device.' });
    }
  };

  const handleSavePrediction = async () => {
    if (!match) return;

    if (!canPredict) {
      setSaveFeedback({
        tone: 'error',
        message: 'Prediction entry is currently disabled.',
      });
      return;
    }

    if (
      draft.resultCode == null &&
      draft.over25 == null &&
      draft.btts == null &&
      draft.homeGoals == null &&
      draft.awayGoals == null
    ) {
      setSaveFeedback({
        tone: 'error',
        message: 'Select at least one lean prediction before saving.',
      });
      return;
    }

    setIsSaving(true);
    setSaveFeedback(null);

    const result = await api.submitPredictionEntry({
      matchId: match.id,
      predictedResultCode: draft.resultCode,
      predictedOver25: draft.over25,
      predictedBtts: draft.btts,
      predictedHomeGoals: draft.homeGoals,
      predictedAwayGoals: draft.awayGoals,
    });

    if (!result.success) {
      setIsSaving(false);
      setSaveFeedback({
        tone: 'error',
        message: result.error ?? 'Could not save your prediction.',
      });
      return;
    }

    const [nextPrediction, nextConsensus] = await Promise.all([
      api.getMyPredictionForMatch(match.id),
      api.getMatchPredictionConsensus(match.id),
    ]);

    setPrediction(nextPrediction);
    setConsensus(nextConsensus);
    setIsSaving(false);
    setSaveFeedback({
      tone: 'success',
      message: 'Prediction saved. It will be scored when the match is settled.',
    });
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
        <header className="pt-6 lg:pt-8 pb-4 px-4 flex items-center justify-between border-b border-border bg-surface2 lg:bg-transparent">
          <Link to="/" className="text-text hover:text-accent transition-all">
            <ChevronLeft size={24} />
          </Link>
          <div className="text-center">
            <div className="text-[10px] font-bold text-muted uppercase tracking-widest">
              Match
            </div>
            <div className="text-sm font-bold text-text">Loading</div>
          </div>
          <div className="w-12" />
        </header>
        <div className="flex flex-col items-center justify-center py-24 gap-4">
          <Loader2 className="animate-spin text-accent" size={32} />
          <div className="text-sm font-bold text-muted animate-pulse">
            Loading lean match data...
          </div>
        </div>
      </div>
    );
  }

  if (!match) {
    return (
      <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
        <header className="pt-6 lg:pt-8 pb-4 px-4 flex items-center justify-between border-b border-border bg-surface2 lg:bg-transparent">
          <Link to="/" className="text-text hover:text-accent transition-all">
            <ChevronLeft size={24} />
          </Link>
          <div className="text-center">
            <div className="text-[10px] font-bold text-muted uppercase tracking-widest">
              Match
            </div>
            <div className="text-sm font-bold text-text">Unavailable</div>
          </div>
          <div className="w-12" />
        </header>
        <div className="p-6">
          <div className="bg-surface2 rounded-2xl border border-border p-6 text-sm text-muted">
            {loadError ?? 'This match is no longer available.'}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      <header className="pt-6 lg:pt-8 pb-4 px-4 flex items-center justify-between border-b border-border bg-surface2 lg:bg-transparent">
        <Link to="/" className="text-text hover:text-accent transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">
            {match.competitionLabel}
            {match.matchdayOrRound ? ` · ${match.matchdayOrRound}` : ''}
          </div>
          <div className="text-sm font-bold text-text">
            {match.homeTeam} vs {match.awayTeam}
          </div>
        </div>
        <div className="flex gap-4">
          <button
            onClick={handleShare}
            className="text-muted hover:text-accent transition-all"
            aria-label="Share match"
          >
              <Share2 size={20} />
            </button>
          {showNotifications && (
            <Link
              to="/notifications"
              className="text-muted hover:text-accent transition-all"
              aria-label="Open notifications"
            >
              <Bell size={20} />
            </Link>
          )}
        </div>
      </header>

      <div className="bg-surface2 p-8 flex flex-col items-center gap-6 border-b border-border">
        <div className="flex justify-between items-center w-full max-w-sm">
          <div className="flex flex-col items-center gap-2">
            <div className="w-16 h-16 rounded-full bg-surface3 flex items-center justify-center shadow-inner overflow-hidden border border-border">
              <TeamLogo
                teamName={match.homeTeam}
                src={match.homeLogoUrl}
                size={64}
                className="w-full h-full object-contain p-2"
              />
            </div>
            <span className="font-bold text-sm">
              {match.homeTeam.slice(0, 3).toUpperCase()}
            </span>
          </div>
          <div className="font-mono text-4xl font-bold">
            {match.score ?? 'vs'}
          </div>
          <div className="flex flex-col items-center gap-2">
            <div className="w-16 h-16 rounded-full bg-surface3 flex items-center justify-center shadow-inner overflow-hidden border border-border">
              <TeamLogo
                teamName={match.awayTeam}
                src={match.awayLogoUrl}
                size={64}
                className="w-full h-full object-contain p-2"
              />
            </div>
            <span className="font-bold text-sm">
              {match.awayTeam.slice(0, 3).toUpperCase()}
            </span>
          </div>
        </div>
        <div className="flex items-center gap-2 text-xs font-bold text-accent bg-accent/10 px-3 py-1 rounded-full">
          <span className={`w-2 h-2 rounded-full ${match.isLive ? 'bg-accent animate-pulse' : 'bg-accent/70'}`} />
          {match.isLive ? `${match.timeLabel} LIVE` : `${match.dateLabel} · ${match.kickoffLabel}`}
        </div>
      </div>

      <div className="flex border-b border-border bg-surface overflow-x-auto hide-scrollbar">
        {visibleTabs.map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-none px-6 py-4 text-sm font-bold transition-all whitespace-nowrap ${
              activeTab === tab
                ? 'text-accent border-b-2 border-accent'
                : 'text-muted hover:text-text'
            }`}
          >
            {tab === 'Insights' && <Sparkles size={14} className="inline mr-1 -mt-0.5" />}
            {tab}
          </button>
        ))}
      </div>

      <div className="p-6">
        {canPredict && activeTab === 'Predict' && (
          <PredictTab
            match={match}
            prediction={prediction}
            draft={draft}
            isSaving={isSaving}
            feedback={saveFeedback}
            onSelectResult={handleSelectResult}
            onSelectBtts={(value) => setDraft((current) => ({ ...current, btts: value }))}
            onSelectOver25={(value) => setDraft((current) => ({ ...current, over25: value }))}
            onOpenOptions={() => setIsPredictionOptionsOpen(true)}
            onSave={handleSavePrediction}
          />
        )}
        {activeTab === 'Insights' && (
          <InsightsTab
            match={match}
            engine={engine}
            consensus={consensus}
            homeForm={homeForm}
            awayForm={awayForm}
          />
        )}
        {activeTab === 'Stats' && (
          <StatsTab
            homeTeam={match.homeTeam}
            awayTeam={match.awayTeam}
            homeStanding={homeStanding}
            awayStanding={awayStanding}
            homeForm={homeForm}
            awayForm={awayForm}
          />
        )}
        {activeTab === 'Comments' && <CommentsTab />}
      </div>

      {predictionSummary && (
        <div className="px-6 pb-4">
          <div className="bg-surface2 rounded-2xl border border-border p-4 grid grid-cols-2 gap-3 text-sm">
            <SummaryItem label="Result" value={predictionSummary.result} />
            <SummaryItem label="Exact Score" value={predictionSummary.scoreline} />
            <SummaryItem label="Goals" value={predictionSummary.goals} />
            <SummaryItem label="BTTS" value={predictionSummary.btts} />
          </div>
        </div>
      )}

      {canPredict && (
        <PredictionOptionsSheet
          isOpen={isPredictionOptionsOpen}
          onClose={() => setIsPredictionOptionsOpen(false)}
          homeTeam={match.homeTeam}
          awayTeam={match.awayTeam}
          selectedHomeGoals={draft.homeGoals}
          selectedAwayGoals={draft.awayGoals}
          suggestedHomeGoals={engine?.predictedHomeGoals ?? null}
          suggestedAwayGoals={engine?.predictedAwayGoals ?? null}
          onSelectScore={handleSelectScore}
          onClearScore={() =>
            setDraft((current) => ({ ...current, homeGoals: null, awayGoals: null }))
          }
        />
      )}
    </div>
  );
}

function PredictTab({
  match,
  prediction,
  draft,
  isSaving,
  feedback,
  onSelectResult,
  onSelectBtts,
  onSelectOver25,
  onOpenOptions,
  onSave,
}: {
  match: Match;
  prediction: UserPrediction | null;
  draft: PredictionDraft;
  isSaving: boolean;
  feedback: { tone: 'success' | 'error'; message: string } | null;
  onSelectResult: (resultCode: string) => void;
  onSelectBtts: (value: boolean) => void;
  onSelectOver25: (value: boolean) => void;
  onOpenOptions: () => void;
  onSave: () => void;
}) {
  const exactScoreLabel =
    draft.homeGoals != null && draft.awayGoals != null
      ? `${draft.homeGoals}-${draft.awayGoals}`
      : prediction?.predictedHomeGoals != null && prediction.predictedAwayGoals != null
        ? `${prediction.predictedHomeGoals}-${prediction.predictedAwayGoals}`
        : 'Add exact score';

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="font-display text-xl text-text tracking-widest">MATCH PICKS</h3>
        <button
          onClick={onOpenOptions}
          className="flex items-center gap-2 text-xs font-bold text-accent bg-accent/10 px-3 py-2 rounded-lg hover:bg-accent/20 transition-all"
        >
          <Plus size={14} /> Exact Score
        </button>
      </div>

      <MarketGroup
        title="Match Result"
        options={[
          { value: 'H', label: '1', subtitle: match.homeTeam },
          { value: 'D', label: 'X', subtitle: 'Draw' },
          { value: 'A', label: '2', subtitle: match.awayTeam },
        ]}
        selectedValue={draft.resultCode}
        onSelect={onSelectResult}
      />

      <MarketGroup
        title="Both Teams to Score"
        options={[
          { value: 'yes', label: 'Yes', subtitle: 'Both score' },
          { value: 'no', label: 'No', subtitle: 'One blanks' },
        ]}
        selectedValue={
          draft.btts == null ? null : draft.btts ? 'yes' : 'no'
        }
        onSelect={(value) => onSelectBtts(value === 'yes')}
        columns={2}
      />

      <MarketGroup
        title="Over / Under 2.5"
        options={[
          { value: 'over', label: 'Over', subtitle: '3+ goals' },
          { value: 'under', label: 'Under', subtitle: '0-2 goals' },
        ]}
        selectedValue={
          draft.over25 == null ? null : draft.over25 ? 'over' : 'under'
        }
        onSelect={(value) => onSelectOver25(value === 'over')}
        columns={2}
      />

      <div className="bg-surface2 p-4 rounded-2xl border border-border flex items-center justify-between gap-4">
        <div>
          <div className="text-xs font-bold text-muted mb-1">Exact Score</div>
          <div className="font-mono text-lg font-bold text-text">{exactScoreLabel}</div>
        </div>
        <button
          onClick={onOpenOptions}
          className="rounded-xl border border-border bg-surface3 px-4 py-3 text-sm font-bold text-text hover:border-accent transition-colors"
        >
          Edit
        </button>
      </div>

      {feedback && (
        <div
          className={`rounded-2xl border p-4 text-sm ${
            feedback.tone === 'success'
              ? 'border-success/20 bg-success/10 text-text'
              : 'border-danger/20 bg-danger/10 text-text'
          }`}
        >
          {feedback.message}
        </div>
      )}

      {prediction && (
        <div className="bg-surface2 p-4 rounded-2xl border border-border text-sm text-muted">
          Reward status: <span className="font-bold text-text">{prediction.rewardStatus.replace('_', ' ')}</span>
          {' · '}
          Points awarded: <span className="font-bold text-text">{prediction.pointsAwarded}</span>
        </div>
      )}

      <button
        onClick={onSave}
        disabled={isSaving}
        className="w-full bg-accent text-bg font-bold py-4 rounded-2xl transition-all disabled:opacity-40 disabled:cursor-not-allowed"
      >
        {isSaving ? 'Saving...' : 'Save Free Pick'}
      </button>
    </div>
  );
}

function MarketGroup({
  title,
  options,
  selectedValue,
  onSelect,
  columns = 3,
}: {
  title: string;
  options: Array<{ value: string; label: string; subtitle: string }>;
  selectedValue: string | null;
  onSelect: (value: string) => void;
  columns?: 2 | 3;
}) {
  return (
    <div className="bg-surface2 p-4 rounded-2xl border border-border">
      <div className="text-xs font-bold text-muted mb-3">{title}</div>
      <div className={`grid gap-2 ${columns === 2 ? 'grid-cols-2' : 'grid-cols-3'}`}>
        {options.map((option) => {
          const isSelected = option.value === selectedValue;
          return (
            <button
              key={option.value}
              onClick={() => onSelect(option.value)}
              className={`rounded-xl p-3 flex flex-col items-center transition-all border ${
                isSelected
                  ? 'border-accent bg-accent/10 text-accent'
                  : 'bg-surface3 hover:bg-surface3/80 border-border text-text'
              }`}
            >
              <span className="text-[10px] font-bold text-muted mb-1">{option.label}</span>
              <span className="font-mono text-sm font-bold">{option.subtitle}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function InsightsTab({
  match,
  engine,
  consensus,
  homeForm,
  awayForm,
}: {
  match: Match;
  engine: PredictionEngineOutput | null;
  consensus: PredictionConsensus | null;
  homeForm: TeamFormFeature | null;
  awayForm: TeamFormFeature | null;
}) {
  const strongestOutcome = engine
    ? [
        { label: `${match.homeTeam} win`, value: toPercent(engine.homeWinScore) },
        { label: 'Draw', value: toPercent(engine.drawScore) },
        { label: `${match.awayTeam} win`, value: toPercent(engine.awayWinScore) },
      ].sort((left, right) => right.value - left.value)[0]
    : null;

  return (
    <div className="space-y-4">
      <div className="bg-surface2 rounded-2xl border border-accent/20 p-6 shadow-lg shadow-accent/5">
        <div className="flex items-center gap-2 mb-4 text-accent">
          <Sparkles size={20} />
          <h3 className="font-display text-lg tracking-widest">MATCH INSIGHTS</h3>
        </div>
        <div className="space-y-4 text-sm text-text leading-relaxed">
          <p>
            Lean analysis is built from match form, standings, and the current
            prediction engine output. No injuries, xG, event streams, or betting
            odds are used in this view.
          </p>
          {engine && strongestOutcome && (
            <div className="bg-surface3 rounded-2xl border border-border p-4">
              <div className="text-[10px] font-bold text-muted uppercase tracking-widest mb-1">
                Model Lean
              </div>
              <div className="font-bold text-text">
                {strongestOutcome.label} · {strongestOutcome.value}% confidence
              </div>
              <div className="text-muted mt-1">
                Suggested score: {engine.predictedHomeGoals ?? '-'} - {engine.predictedAwayGoals ?? '-'}
                {' · '}
                Confidence: {engine.confidenceLabel}
              </div>
            </div>
          )}
          {consensus && (
            <div className="bg-surface3 rounded-2xl border border-border p-4">
              <div className="text-[10px] font-bold text-muted uppercase tracking-widest mb-2">
                Community Consensus
              </div>
              <div className="grid grid-cols-3 gap-2 text-center">
                <InsightMetric label={match.homeTeam} value={`${consensus.homePct}%`} />
                <InsightMetric label="Draw" value={`${consensus.drawPct}%`} />
                <InsightMetric label={match.awayTeam} value={`${consensus.awayPct}%`} />
              </div>
            </div>
          )}
          {(homeForm || awayForm) && (
            <div className="grid grid-cols-2 gap-3">
              <FormCard teamName={match.homeTeam} form={homeForm} />
              <FormCard teamName={match.awayTeam} form={awayForm} />
            </div>
          )}
          {!engine && !consensus && !homeForm && !awayForm && (
            <div className="text-muted">
              Lean predictions are not available for this fixture yet. Once the
              form features and engine outputs are generated, this panel will update automatically.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function StatsTab({
  homeTeam,
  awayTeam,
  homeStanding,
  awayStanding,
  homeForm,
  awayForm,
}: {
  homeTeam: string;
  awayTeam: string;
  homeStanding: StandingRow | null;
  awayStanding: StandingRow | null;
  homeForm: TeamFormFeature | null;
  awayForm: TeamFormFeature | null;
}) {
  const stats = [
    {
      label: 'Season Points',
      left: String(homeStanding?.points ?? 0),
      right: String(awayStanding?.points ?? 0),
      leftValue: homeStanding?.points ?? 0,
      rightValue: awayStanding?.points ?? 0,
    },
    {
      label: 'Goal Difference',
      left: String(homeStanding?.goalDifference ?? 0),
      right: String(awayStanding?.goalDifference ?? 0),
      leftValue: Math.max(0, homeStanding?.goalDifference ?? 0),
      rightValue: Math.max(0, awayStanding?.goalDifference ?? 0),
    },
    {
      label: 'Last 5 Points',
      left: String(homeForm?.last5Points ?? 0),
      right: String(awayForm?.last5Points ?? 0),
      leftValue: homeForm?.last5Points ?? 0,
      rightValue: awayForm?.last5Points ?? 0,
    },
    {
      label: 'Goals Scored (L5)',
      left: String(homeForm?.last5GoalsFor ?? 0),
      right: String(awayForm?.last5GoalsFor ?? 0),
      leftValue: homeForm?.last5GoalsFor ?? 0,
      rightValue: awayForm?.last5GoalsFor ?? 0,
    },
    {
      label: 'Clean Sheets (L5)',
      left: String(homeForm?.last5CleanSheets ?? 0),
      right: String(awayForm?.last5CleanSheets ?? 0),
      leftValue: homeForm?.last5CleanSheets ?? 0,
      rightValue: awayForm?.last5CleanSheets ?? 0,
    },
  ];

  const hasStats = stats.some((stat) => stat.leftValue > 0 || stat.rightValue > 0);

  if (!hasStats) {
    return (
      <div className="bg-surface2 p-6 rounded-2xl border border-border text-sm text-muted">
        Lean comparison stats are not available yet for {homeTeam} vs {awayTeam}.
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <StatsPanel stats={stats} />
    </div>
  );
}

function CommentsTab() {
  return (
    <div className="bg-surface2 p-6 rounded-2xl border border-border text-center">
      <div className="w-12 h-12 rounded-full bg-surface3 border border-border text-muted mx-auto mb-4 flex items-center justify-center">
        <MessageSquare size={20} />
      </div>
      <div className="font-bold text-text mb-2">Comments are not part of the lean stack</div>
      <p className="text-sm text-muted leading-relaxed">
        Match discussion was removed from the retained prediction product flow.
        This screen now focuses on fixtures, form, standings, predictions, and rewards.
      </p>
    </div>
  );
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] font-bold uppercase tracking-widest text-muted mb-1">
        {label}
      </div>
      <div className="font-bold text-text">{value}</div>
    </div>
  );
}

function InsightMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-border bg-surface2 p-3">
      <div className="text-[10px] font-bold uppercase tracking-widest text-muted truncate">
        {label}
      </div>
      <div className="font-mono text-lg font-bold text-text mt-1">{value}</div>
    </div>
  );
}

function FormCard({
  teamName,
  form,
}: {
  teamName: string;
  form: TeamFormFeature | null;
}) {
  return (
    <div className="rounded-2xl border border-border bg-surface3 p-4">
      <div className="text-[10px] font-bold uppercase tracking-widest text-muted mb-2">
        {teamName}
      </div>
      {form ? (
        <div className="space-y-2 text-sm text-text">
          <div>Last 5 points: {form.last5Points}</div>
          <div>Record: {form.last5Wins}W {form.last5Draws}D {form.last5Losses}L</div>
          <div>Goals: {form.last5GoalsFor} scored · {form.last5GoalsAgainst} conceded</div>
        </div>
      ) : (
        <div className="text-sm text-muted">Form features not generated yet.</div>
      )}
    </div>
  );
}
