import {
  ArrowRight,
  Trophy,
  Wallet,
  Shield,
  Target,
  Users,
  Star,
  ChevronDown,
  Zap,
  TrendingUp,
  Award,
  Download,
} from "lucide-react";
import { Link } from "react-router-dom";
import { renderFanzoneText } from "../components/FanzoneWordmark";

const LEAGUES = [
  { emoji: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", name: "Premier League" },
  { emoji: "🇪🇸", name: "La Liga" },
  { emoji: "🇮🇹", name: "Serie A" },
  { emoji: "🇩🇪", name: "Bundesliga" },
  { emoji: "🇫🇷", name: "Ligue 1" },
  { emoji: "🏆", name: "Champions League" },
  { emoji: "🌍", name: "Europa League" },
  { emoji: "⚽", name: "World Cup / Euros" },
];

export default function Home() {
  return (
    <div>
      {/* ── Hero Section ── */}
      <section className="hero">
        <div className="hero-gradient" />
        <div className="hero-grid" />

        <div className="hero-content fade-in-up">
          <div className="badge mb-6" style={{ margin: "0 auto 24px" }}>
            <span
              className="badge-dot"
              style={{ background: "var(--fz-accent)" }}
            />
            <span>The Ultimate Football Platform</span>
          </div>

          <h1 className="hero-title">
            Every Match
            <br />
            <span className="highlight">Means More.</span>
          </h1>

          <p
            className="text-lg text-secondary fade-in-up fade-in-up-delay-1"
            style={{ maxWidth: 560, margin: "0 auto 32px" }}
          >
            Predict scores, climb leaderboards, earn FET tokens, and redeem
            real-world rewards. Free to play. Built for real fans.
          </p>

          <div className="flex gap-4 justify-center flex-wrap fade-in-up fade-in-up-delay-2">
            <a
              href="#download"
              id="hero-download-cta"
              className="btn btn-primary btn-lg"
            >
              <Download size={18} />
              Download App
            </a>
            <Link to="/overview" className="btn btn-outline btn-lg">
              How it Works
              <ArrowRight size={16} />
            </Link>
          </div>
        </div>

        <div className="scroll-indicator desktop-only">
          <ChevronDown size={20} />
        </div>
      </section>

      {/* ── Stats Strip ── */}
      <section style={{ padding: "0 0 64px" }}>
        <div className="container fade-in-up fade-in-up-delay-3">
          <div className="stats-strip">
            <div className="stat-card">
              <div className="stat-value text-accent">8+</div>
              <div className="stat-label">Competitions</div>
            </div>
            <div className="stat-card">
              <div className="stat-value text-success">100M</div>
              <div className="stat-label">FET Token Cap</div>
            </div>
            <div className="stat-card">
              <div className="stat-value text-coral">∞</div>
              <div className="stat-label">Free Predictions</div>
            </div>
            <div className="stat-card">
              <div className="stat-value text-blue">🌍</div>
              <div className="stat-label">Global Reach</div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Feature Cards ── */}
      <section className="section" style={{ background: "var(--fz-surface)" }}>
        <div className="container">
          <div className="section-header">
            <h2>Built for Real Fans</h2>
            <p>
              {renderFanzoneText(
                "Three pillars of the FANZONE experience — predictions, rewards, and community.",
              )}
            </p>
          </div>

          <div className="feature-grid">
            <div
              className="glass-card feature-card fade-in-up"
              style={{ textAlign: "center", alignItems: "center" }}
            >
              <div
                className="icon-box"
                style={{ background: "rgba(152, 255, 152, 0.1)" }}
              >
                <Trophy size={28} color="var(--fz-accent)" />
              </div>
              <h3 className="text-xl font-bold">Predict & Win</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.6 }}>
                Join daily challenges, predict match outcomes, and compete on
                global leaderboards. Every correct prediction earns FET tokens.
              </p>
              <Link
                to="/overview"
                className="flex items-center gap-1 text-accent text-sm font-semibold mt-auto"
                style={{ paddingTop: "8px" }}
              >
                Learn More <ArrowRight size={14} />
              </Link>
            </div>

            <div
              className="glass-card feature-card fade-in-up fade-in-up-delay-1"
              style={{ textAlign: "center", alignItems: "center" }}
            >
              <div
                className="icon-box"
                style={{ background: "rgba(152, 255, 152, 0.08)" }}
              >
                <Wallet size={28} color="var(--fz-success)" />
              </div>
              <h3 className="text-xl font-bold">The FET Economy</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.6 }}>
                Earn internal FET tokens through engagement and accuracy. Redeem
                them at select partner locations for exclusive deals and
                merchandise.
              </p>
              <Link
                to="/fet"
                className="flex items-center gap-1 text-accent text-sm font-semibold mt-auto"
                style={{ paddingTop: "8px" }}
              >
                Token Details <ArrowRight size={14} />
              </Link>
            </div>

            <div
              className="glass-card feature-card fade-in-up fade-in-up-delay-2"
              style={{ textAlign: "center", alignItems: "center" }}
            >
              <div
                className="icon-box"
                style={{ background: "rgba(255, 127, 80, 0.1)" }}
              >
                <Shield size={28} color="var(--fz-blue)" />
              </div>
              <h3 className="text-xl font-bold">One-Tap Access</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.6 }}>
                Login seamlessly via WhatsApp OTP — one real person per account,
                zero bots. Browse as a guest or upgrade when you're ready to
                play.
              </p>
              <Link
                to="/guest-auth"
                className="flex items-center gap-1 text-accent text-sm font-semibold mt-auto"
                style={{ paddingTop: "8px" }}
              >
                Access Model <ArrowRight size={14} />
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ── Leagues Strip ── */}
      <section className="section">
        <div className="container">
          <div className="section-header">
            <h2>Top-Flight Coverage</h2>
            <p>
              We focus on the leagues and competitions that matter most to real
              fans.
            </p>
          </div>

          <div className="league-strip">
            {LEAGUES.map((l) => (
              <div key={l.name} className="league-chip">
                <span style={{ fontSize: "1.25rem" }}>{l.emoji}</span>
                {l.name}
              </div>
            ))}
          </div>

          <div style={{ textAlign: "center", marginTop: "24px" }}>
            <Link to="/coverage" className="btn btn-ghost text-sm">
              View all coverage <ArrowRight size={14} />
            </Link>
          </div>
        </div>
      </section>

      {/* ── How it Works ── */}
      <section className="section" style={{ background: "var(--fz-surface)" }}>
        <div className="container">
          <div className="section-header">
            <h2>How it Works</h2>
            <p>
              From first download to your first reward — in three simple steps.
            </p>
          </div>

          <div className="step-section">
            <div className="glass-card step-card fade-in-up">
              <div className="step-number">
                <Target size={22} />
              </div>
              <h3 className="text-xl font-bold mb-3">Predict</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
                Browse live matches from Europe's top leagues. Place free
                prediction slips on match outcomes. Join prediction pools with
                friends and stake FET tokens.
              </p>
            </div>

            <div className="glass-card step-card fade-in-up fade-in-up-delay-1">
              <div
                className="step-number"
                style={{
                  borderColor: "var(--fz-accent)",
                  color: "var(--fz-success)",
                }}
              >
                <TrendingUp size={22} />
              </div>
              <h3 className="text-xl font-bold mb-3">Earn</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
                Every correct prediction earns FET tokens to your secure wallet.
                Complete daily challenges for bonus rewards. Climb the
                leaderboard and build your reputation.
              </p>
            </div>

            <div className="glass-card step-card fade-in-up fade-in-up-delay-2">
              <div
                className="step-number"
                style={{
                  borderColor: "var(--fz-accent)",
                  color: "var(--fz-coral)",
                }}
              >
                <Award size={22} />
              </div>
              <h3 className="text-xl font-bold mb-3">Redeem</h3>
              <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
                Browse our partner marketplace. Redeem FET tokens for exclusive
                deals, discounts, and merchandise at select partner locations
                worldwide.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ── Community Section ── */}
      <section className="section">
        <div className="container">
          <div
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 1fr",
              gap: "48px",
              alignItems: "center",
            }}
          >
            <div className="fade-in-up">
              <div className="badge mb-4">
                <Users size={14} />
                <span>Fan Communities</span>
              </div>
              <h2 className="text-4xl font-bold mb-6" style={{ maxWidth: 500 }}>
                Your Team,
                <br />
                <span className="text-accent">Your Identity.</span>
              </h2>
              <p
                className="text-secondary mb-6"
                style={{ lineHeight: 1.7, maxWidth: 480 }}
              >
                Football is tribal. Join team communities, contribute to your
                club's strength meter, read AI-curated team news, and build your
                fan identity — all without revealing who you are.
              </p>
              <div className="flex flex-col gap-3">
                <div className="flex items-center gap-3">
                  <Star size={18} color="var(--fz-coral)" />
                  <span className="text-sm">Anonymous fan identities</span>
                </div>
                <div className="flex items-center gap-3">
                  <Zap size={18} color="var(--fz-accent)" />
                  <span className="text-sm">
                    AI-curated team news via Gemini
                  </span>
                </div>
                <div className="flex items-center gap-3">
                  <Users size={18} color="var(--fz-success)" />
                  <span className="text-sm">Community contribution meters</span>
                </div>
              </div>
            </div>

            <div
              className="glass-card fade-in-up fade-in-up-delay-2"
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "16px",
                padding: "32px",
              }}
            >
              {["Liverpool FC", "Real Madrid CF", "FC Bayern München"].map(
                (team, i) => (
                  <div
                    key={team}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "16px",
                      padding: "16px",
                      background: "var(--fz-surface-2)",
                      borderRadius: "12px",
                      border: "1px solid var(--fz-border)",
                    }}
                  >
                    <div
                      style={{
                        width: 44,
                        height: 44,
                        borderRadius: 10,
                        background:
                          i === 0
                            ? "rgba(239, 68, 68, 0.15)"
                            : i === 1
                              ? "rgba(253, 252, 240, 0.08)"
                              : "rgba(239, 68, 68, 0.12)",
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        fontSize: "1.25rem",
                      }}
                    >
                      {i === 0 ? "🔴" : i === 1 ? "⚪" : "🔴"}
                    </div>
                    <div style={{ flex: 1 }}>
                      <div className="text-sm font-bold">{team}</div>
                      <div className="text-xs text-muted">
                        {(1240 - i * 310).toLocaleString()} supporters
                      </div>
                    </div>
                    <div
                      style={{
                        padding: "4px 10px",
                        borderRadius: "20px",
                        background: "rgba(152, 255, 152, 0.1)",
                        color: "var(--fz-accent)",
                        fontSize: "0.6875rem",
                        fontWeight: 700,
                      }}
                    >
                      JOIN
                    </div>
                  </div>
                ),
              )}
            </div>
          </div>

          {/* Responsive override */}
          <style>{`
            @media (max-width: 768px) {
              .section > .container > div[style*="grid-template-columns: 1fr 1fr"] {
                grid-template-columns: 1fr !important;
              }
            }
          `}</style>
        </div>
      </section>

      {/* ── CTA Banner ── */}
      <section className="section-lg" id="download">
        <div className="container">
          <div className="cta-banner fade-in-up">
            <h2
              className="text-4xl font-bold mb-4"
              style={{ position: "relative" }}
            >
              Ready to Enter the <span className="text-accent">Fanzone</span>?
            </h2>
            <p
              className="text-secondary mb-8"
              style={{
                maxWidth: 500,
                margin: "0 auto 32px",
                position: "relative",
              }}
            >
              Available on Android and iOS. Join the community, predict matches,
              and start earning today. Free to download. Free to play.
            </p>
            <div
              className="flex gap-4 justify-center flex-wrap"
              style={{ position: "relative" }}
            >
              {/* TODO: Replace # with real store URLs when available */}
              <a
                href="#"
                id="cta-app-store"
                className="btn"
                style={{
                  background: "var(--fz-text)",
                  color: "var(--fz-bg)",
                  padding: "14px 28px",
                  fontWeight: 700,
                  gap: "10px",
                }}
              >
                <span style={{ fontSize: "1.5rem" }}>🍎</span>
                App Store
              </a>
              <a
                href="#"
                id="cta-google-play"
                className="btn"
                style={{
                  background: "var(--fz-text)",
                  color: "var(--fz-bg)",
                  padding: "14px 28px",
                  fontWeight: 700,
                  gap: "10px",
                }}
              >
                <span style={{ fontSize: "1.5rem" }}>▶️</span>
                Google Play
              </a>
            </div>
            <p
              className="text-xs text-muted"
              style={{ marginTop: "16px", position: "relative" }}
            >
              Not a gambling platform. FET tokens have no fiat monetary value.
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
