import { useMemo } from "react";
import {
  AlertTriangle,
  Clock,
  QrCode,
  RefreshCw,
  Trophy,
  Users,
  Utensils,
} from "lucide-react";
import {
  safeImageUrl,
  type Json,
  type MenuItemRow,
  type Venue,
} from "@fanzone/core";
import { useQrCode } from "../hooks/useQrCode";
import {
  buildJoinUrl,
  formatCurrency,
  formatTime,
  parseOptions,
  readable,
  readableMode,
} from "../lib/displayUtils";
import type {
  TvGameDisplay,
  TvPoolDisplay,
  VenueScreenMode,
} from "../services/tvData";
import type { ScreenData } from "../types";

export function TvShell({
  data,
  onReload,
}: {
  data: ScreenData;
  onReload: () => void;
}) {
  const mode = data.state?.mode ?? "welcome";
  const joinUrl = useMemo(
    () => buildJoinUrl(data.venue, data.state),
    [data.venue, data.state],
  );
  const qrDataUrl = useQrCode(joinUrl);
  const logoUrl = safeImageUrl(data.venue?.logoUrl);

  return (
    <main className="tv-shell">
      <ScreenBackdrop venue={data.venue} mode={mode} />
      <header className="screen-header">
        <div className="venue-lockup">
          {logoUrl ? (
            <img src={logoUrl} alt="" />
          ) : (
            <div className="logo-fallback">FZ</div>
          )}
          <div>
            <p>{data.venue?.country ?? "Venue"}</p>
            <h1>{data.venue?.name ?? "FANZONE"}</h1>
          </div>
        </div>
        <div className="status-strip">
          <span>{readableMode(mode)}</span>
          <small>
            {data.refreshedAt ? formatTime(data.refreshedAt) : "Syncing"}
          </small>
          <button type="button" onClick={onReload} aria-label="Refresh screen">
            <RefreshCw size={18} />
          </button>
        </div>
      </header>

      {data.error ? (
        <ErrorScreen message={data.error} />
      ) : data.loading && !data.venue ? (
        <LoadingScreen />
      ) : (
        <ScreenBody
          data={data}
          mode={mode}
          joinUrl={joinUrl}
          qrDataUrl={qrDataUrl}
        />
      )}
    </main>
  );
}

function ScreenBody({
  data,
  mode,
  joinUrl,
  qrDataUrl,
}: {
  data: ScreenData;
  mode: VenueScreenMode;
  joinUrl: string;
  qrDataUrl: string | null;
}) {
  if (mode === "pool") {
    return (
      <PoolScreen pool={data.pool} qrDataUrl={qrDataUrl} joinUrl={joinUrl} />
    );
  }

  if (mode === "game_lobby") {
    return (
      <GameLobbyScreen
        game={data.game}
        qrDataUrl={qrDataUrl}
        joinUrl={joinUrl}
      />
    );
  }

  if (mode === "game_question") {
    return <GameQuestionScreen game={data.game} qrDataUrl={qrDataUrl} />;
  }

  if (mode === "leaderboard") {
    return <LeaderboardScreen game={data.game} pool={data.pool} />;
  }

  if (mode === "winners") {
    return <WinnersScreen game={data.game} pool={data.pool} />;
  }

  if (mode === "menu" || mode === "promo") {
    return (
      <MenuPromoScreen
        items={data.menuItems}
        qrDataUrl={qrDataUrl}
        joinUrl={joinUrl}
      />
    );
  }

  return (
    <JoinScreen
      venue={data.venue}
      qrDataUrl={qrDataUrl}
      joinUrl={joinUrl}
      mode={mode}
    />
  );
}

function ScreenBackdrop({
  venue,
  mode,
}: {
  venue: Venue | null;
  mode: VenueScreenMode;
}) {
  const imageUrl =
    safeImageUrl(venue?.coverUrl) ?? safeImageUrl(venue?.logoUrl);
  return (
    <div className={`screen-backdrop mode-${mode}`}>
      {imageUrl && <img src={imageUrl} alt="" />}
      <div />
    </div>
  );
}

function JoinScreen({
  venue,
  qrDataUrl,
  joinUrl,
  mode,
}: {
  venue: Venue | null;
  qrDataUrl: string | null;
  joinUrl: string;
  mode: VenueScreenMode;
}) {
  return (
    <section className="hero-screen">
      <div className="hero-copy">
        <p className="eyebrow">{mode === "qr" ? "Scan to join" : "Welcome"}</p>
        <h2>{venue?.name ?? "Venue"} is live on FANZONE</h2>
        <p>
          Browse the menu, join venue-linked pools and games, and place a
          qualifying order before play starts to unlock FET settlement
          eligibility.
        </p>
        <EligibilityTicker />
      </div>
      <QrPanel
        qrDataUrl={qrDataUrl}
        joinUrl={joinUrl}
        label="Join this venue"
      />
    </section>
  );
}

function PoolScreen({
  pool,
  qrDataUrl,
  joinUrl,
}: {
  pool: TvPoolDisplay | null;
  qrDataUrl: string | null;
  joinUrl: string;
}) {
  return (
    <section className="split-screen">
      <div className="screen-card primary-card">
        <p className="eyebrow">Prediction pool</p>
        <h2>{pool?.title ?? "Active prediction pool"}</h2>
        <p className="supporting">{pool?.matchLabel ?? "Venue-linked match"}</p>
        <div className="metric-row">
          <Metric label="Members" value={String(pool?.totalMembers ?? 0)} />
          <Metric
            label="Pot"
            value={`${(pool?.totalStakedFet ?? 0).toLocaleString()} FET`}
          />
          <Metric label="Status" value={readable(pool?.status ?? "open")} />
        </div>
        <CampBars camps={pool?.camps ?? []} />
      </div>
      <QrPanel qrDataUrl={qrDataUrl} joinUrl={joinUrl} label="Join pool" />
    </section>
  );
}

function GameLobbyScreen({
  game,
  qrDataUrl,
  joinUrl,
}: {
  game: TvGameDisplay | null;
  qrDataUrl: string | null;
  joinUrl: string;
}) {
  return (
    <section className="split-screen">
      <div className="screen-card primary-card">
        <p className="eyebrow">Game lobby</p>
        <h2>{game?.session.templateName ?? "Venue game"}</h2>
        <p className="supporting">
          Create or join a team. Minimum 2 teams required before settlement.
        </p>
        <div className="metric-row">
          <Metric label="Teams" value={String(game?.teams.length ?? 0)} />
          <Metric
            label="Reward"
            value={`${(game?.session.rewardFet ?? 0).toLocaleString()} FET`}
          />
          <Metric
            label="Questions"
            value={String(game?.session.selectedQuestionCount ?? 20)}
          />
        </div>
        <TeamList teams={game?.teams ?? []} />
      </div>
      <QrPanel qrDataUrl={qrDataUrl} joinUrl={joinUrl} label="Join game" />
    </section>
  );
}

function GameQuestionScreen({
  game,
  qrDataUrl,
}: {
  game: TvGameDisplay | null;
  qrDataUrl: string | null;
}) {
  const question = game?.currentQuestion;
  return (
    <section className="question-screen">
      <div className="round-pill">
        <Clock size={22} />
        Round {question?.ordinal ??
          game?.session.currentQuestionOrdinal ??
          0} / {game?.session.selectedQuestionCount ?? 20}
      </div>
      <h2>{question?.prompt ?? "Question loading"}</h2>
      <OptionGrid options={question?.options ?? null} />
      <div className="question-footer">
        <span>Only the first correct team earns FET for this question.</span>
        {qrDataUrl && <img src={qrDataUrl} alt="Join QR code" />}
      </div>
    </section>
  );
}

function LeaderboardScreen({
  game,
  pool,
}: {
  game: TvGameDisplay | null;
  pool: TvPoolDisplay | null;
}) {
  const teams = game?.teams ?? [];
  return (
    <section className="leaderboard-screen">
      <p className="eyebrow">Leaderboard</p>
      <h2>{game?.session.templateName ?? pool?.title ?? "Live standings"}</h2>
      {teams.length ? (
        <ol className="leaderboard-list">
          {teams.slice(0, 8).map((team, index) => (
            <li key={team.id}>
              <span>{index + 1}</span>
              <strong>{team.name}</strong>
              <em>{team.scoreFet.toLocaleString()} FET</em>
            </li>
          ))}
        </ol>
      ) : (
        <CampBars camps={pool?.camps ?? []} />
      )}
    </section>
  );
}

function WinnersScreen({
  game,
  pool,
}: {
  game: TvGameDisplay | null;
  pool: TvPoolDisplay | null;
}) {
  const winner = game?.teams[0];
  const winningCamp = pool?.camps.find((camp) => camp.isWinningCamp);
  return (
    <section className="winner-screen">
      <Trophy size={92} />
      <p className="eyebrow">Winner reveal</p>
      <h2>{winner?.name ?? winningCamp?.label ?? "Awaiting settlement"}</h2>
      <p>
        FET settlement is paid only to eligible winners with a paid qualifying
        order from this linked bar inside the 2-hour window before start.
      </p>
    </section>
  );
}

function MenuPromoScreen({
  items,
  qrDataUrl,
  joinUrl,
}: {
  items: MenuItemRow[];
  qrDataUrl: string | null;
  joinUrl: string;
}) {
  return (
    <section className="split-screen menu-screen">
      <div className="screen-card primary-card">
        <p className="eyebrow">Order from the bar</p>
        <h2>Menu highlights</h2>
        {items.length ? (
          <div className="menu-grid">
            {items.map((item) => (
              <article key={item.id}>
                <Utensils size={24} />
                <strong>{item.name}</strong>
                <span>{formatCurrency(item.price, item.currency_code)}</span>
              </article>
            ))}
          </div>
        ) : (
          <p className="supporting">
            Scan to browse the menu and place a qualifying order.
          </p>
        )}
      </div>
      <QrPanel qrDataUrl={qrDataUrl} joinUrl={joinUrl} label="Open menu" />
    </section>
  );
}

function ErrorScreen({ message }: { message: string }) {
  return (
    <section className="center-stage">
      <div className="operator-panel danger-panel">
        <AlertTriangle size={42} />
        <h2>Display needs attention</h2>
        <p>{message}</p>
      </div>
    </section>
  );
}

function LoadingScreen() {
  return (
    <section className="center-stage">
      <div className="loading-mark" />
    </section>
  );
}

function QrPanel({
  qrDataUrl,
  joinUrl,
  label,
}: {
  qrDataUrl: string | null;
  joinUrl: string;
  label: string;
}) {
  return (
    <aside className="qr-panel">
      <div className="qr-paper">
        {qrDataUrl ? (
          <img src={qrDataUrl} alt={`${label} QR code`} />
        ) : (
          <QrCode size={160} />
        )}
      </div>
      <h3>{label}</h3>
      <p>{joinUrl.replace(/^https?:\/\//, "")}</p>
    </aside>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function CampBars({
  camps,
}: {
  camps: Array<{
    id: string;
    label: string;
    memberCount: number;
    totalStakedFet: number;
  }>;
}) {
  const total = camps.reduce((sum, camp) => sum + camp.memberCount, 0);
  if (!camps.length) {
    return (
      <p className="supporting">
        Pool distribution will appear after participants join.
      </p>
    );
  }

  return (
    <div className="camp-bars">
      {camps.map((camp) => {
        const percent =
          total > 0
            ? Math.max(8, Math.round((camp.memberCount / total) * 100))
            : 8;
        return (
          <div key={camp.id}>
            <div>
              <strong>{camp.label}</strong>
              <span>{camp.memberCount} joined</span>
            </div>
            <div className="bar-track">
              <span style={{ width: `${percent}%` }} />
            </div>
            <em>{camp.totalStakedFet.toLocaleString()} FET</em>
          </div>
        );
      })}
    </div>
  );
}

function TeamList({
  teams,
}: {
  teams: Array<{
    id: string;
    name: string;
    scoreFet: number;
    memberCount: number;
  }>;
}) {
  if (!teams.length) {
    return (
      <p className="supporting">
        Teams appear here as guests join the session.
      </p>
    );
  }

  return (
    <div className="team-list">
      {teams.slice(0, 6).map((team) => (
        <article key={team.id}>
          <Users size={24} />
          <strong>{team.name}</strong>
          <span>{team.memberCount} members</span>
          <em>{team.scoreFet.toLocaleString()} FET</em>
        </article>
      ))}
    </div>
  );
}

function OptionGrid({ options }: { options: Json | null }) {
  const values = parseOptions(options);
  if (!values.length) {
    return (
      <p className="supporting">
        Answer options are visible on participant devices.
      </p>
    );
  }

  return (
    <div className="option-grid">
      {values.slice(0, 6).map((option, index) => (
        <div key={`${option}-${index}`}>
          <span>{String.fromCharCode(65 + index)}</span>
          <strong>{option}</strong>
        </div>
      ))}
    </div>
  );
}

function EligibilityTicker() {
  return (
    <div className="eligibility-ticker">
      <span>
        FET winners need a paid order from this bar within 2 hours before start
      </span>
      <span>No cash-out</span>
      <span>Venue-linked play only</span>
    </div>
  );
}
