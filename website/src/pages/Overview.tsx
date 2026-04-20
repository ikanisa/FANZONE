import {
  Target,
  TrendingUp,
  Award,
  CheckCircle2,
  ArrowRight,
} from "lucide-react";
import { Link } from "react-router-dom";
import { renderFanzoneText } from "../components/FanzoneWordmark";

export default function Overview() {
  return (
    <div>
      <div className="page-heading container">
        <h1>{renderFanzoneText("How FANZONE Works")}</h1>
        <p>
          Built for real football fans. Engage with live matches, make smart
          predictions, and grow your reputation and rewards.
        </p>
      </div>

      {/* Step 1: Predict */}
      <section className="section container">
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
              <Target size={14} />
              <span>Step 1</span>
            </div>
            <h2 className="text-3xl font-bold mb-4">
              <span className="text-accent">Predict</span> the Action
            </h2>
            <p className="text-secondary mb-6" style={{ lineHeight: 1.7 }}>
              Use your football knowledge to predict outcomes of top-flight
              matches across Europe's biggest leagues. Join daily challenges,
              place free prediction slips, or create prediction pools with
              friends.
            </p>
            <ul
              style={{ display: "flex", flexDirection: "column", gap: "12px" }}
            >
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-accent)" />
                <span>Free prediction slips — no purchase required</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-accent)" />
                <span>Social prediction pools with FET stakes</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-accent)" />
                <span>Daily challenges with bonus rewards</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-accent)" />
                <span>Dynamic global leaderboards</span>
              </li>
            </ul>
          </div>

          <div
            className="glass-card fade-in-up fade-in-up-delay-1"
            style={{
              display: "flex",
              flexDirection: "column",
              gap: "12px",
              padding: "24px",
            }}
          >
            <div className="text-xs font-semibold tracking-widest uppercase text-muted mb-2">
              Match Day Preview
            </div>
            {[
              {
                home: "Arsenal",
                away: "Chelsea",
                comp: "Premier League",
                time: "15:00",
              },
              {
                home: "Barcelona",
                away: "Real Madrid",
                comp: "La Liga",
                time: "21:00",
              },
              {
                home: "AC Milan",
                away: "Inter Milan",
                comp: "Serie A",
                time: "18:00",
              },
            ].map((match, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  padding: "14px 16px",
                  background: "var(--fz-surface-2)",
                  borderRadius: "12px",
                  border: "1px solid var(--fz-border)",
                }}
              >
                <div>
                  <div className="text-sm font-bold">
                    {match.home} vs {match.away}
                  </div>
                  <div className="text-xs text-muted">{match.comp}</div>
                </div>
                <div
                  style={{
                    padding: "4px 12px",
                    borderRadius: "20px",
                    background: "rgba(152, 255, 152, 0.1)",
                    color: "var(--fz-accent)",
                    fontSize: "0.6875rem",
                    fontWeight: 700,
                  }}
                >
                  PREDICT
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Step 2: Earn */}
      <section className="section container">
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "48px",
            alignItems: "center",
          }}
        >
          <div
            className="glass-card fade-in-up"
            style={{ padding: "32px", order: -1 }}
          >
            <div className="text-xs font-semibold tracking-widest uppercase text-muted mb-4">
              FET Wallet
            </div>
            <div
              style={{
                fontSize: "3rem",
                fontWeight: 900,
                letterSpacing: "-0.03em",
                color: "var(--fz-success)",
                marginBottom: "4px",
              }}
            >
              12,450 FET
            </div>
            <div className="text-sm text-muted mb-6">Available balance</div>
            <div
              style={{ display: "flex", flexDirection: "column", gap: "8px" }}
            >
              {[
                {
                  title: "Prediction Win",
                  amount: "+250 FET",
                  color: "var(--fz-success)",
                },
                {
                  title: "Daily Challenge",
                  amount: "+100 FET",
                  color: "var(--fz-success)",
                },
                {
                  title: "Pool Stake",
                  amount: "-500 FET",
                  color: "var(--fz-coral)",
                },
              ].map((tx, i) => (
                <div
                  key={i}
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    padding: "10px 14px",
                    background: "var(--fz-surface-2)",
                    borderRadius: "8px",
                  }}
                >
                  <span className="text-sm">{tx.title}</span>
                  <span
                    className="text-sm font-bold"
                    style={{ color: tx.color }}
                  >
                    {tx.amount}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <div className="fade-in-up fade-in-up-delay-1">
            <div className="badge mb-4">
              <TrendingUp size={14} />
              <span>Step 2</span>
            </div>
            <h2 className="text-3xl font-bold mb-4">
              <span className="text-success">Earn</span> & Grow
            </h2>
            <p className="text-secondary mb-6" style={{ lineHeight: 1.7 }}>
              Your accuracy and engagement translate directly into FET tokens.
              The internal ledger tracks every earning transparently. Build your
              balance through skill, not luck.
            </p>
            <ul
              style={{ display: "flex", flexDirection: "column", gap: "12px" }}
            >
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-success)" />
                <span>FET tokens for correct predictions</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-success)" />
                <span>5,000 FET welcome grant on sign-up</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-success)" />
                <span>Secure wallet with full transaction history</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-success)" />
                <span>Audited ledger with supply cap governance</span>
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* Step 3: Community */}
      <section className="section container">
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
              <Award size={14} />
              <span>Step 3</span>
            </div>
            <h2 className="text-3xl font-bold mb-4">
              <span className="text-coral">Defend</span> Your Team
            </h2>
            <p className="text-secondary mb-6" style={{ lineHeight: 1.7 }}>
              Football is tribal. Express your identity, join your club's
              community, follow AI-curated team news powered by Gemini, and
              contribute to your team's strength in the rankings.
            </p>
            <ul
              style={{ display: "flex", flexDirection: "column", gap: "12px" }}
            >
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-coral)" />
                <span>Anonymous fan identity system</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-coral)" />
                <span>AI-curated team news via Google Gemini</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-coral)" />
                <span>Community contribution meters</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={20} color="var(--fz-coral)" />
                <span>Team supporter leaderboards</span>
              </li>
            </ul>
          </div>

          <div
            className="glass-card fade-in-up fade-in-up-delay-1"
            style={{
              padding: "32px",
              display: "flex",
              flexDirection: "column",
              gap: "20px",
            }}
          >
            <div className="text-xs font-semibold tracking-widest uppercase text-muted">
              Community Strength
            </div>
            {[
              { team: "Juventus", pct: 82, color: "var(--fz-text)" },
              { team: "Manchester United", pct: 76, color: "var(--fz-danger)" },
              { team: "Paris Saint-Germain", pct: 64, color: "var(--fz-blue)" },
            ].map((entry, i) => (
              <div key={i}>
                <div className="flex justify-between items-center mb-2">
                  <span className="text-sm font-semibold">{entry.team}</span>
                  <span className="text-sm text-muted">{entry.pct}%</span>
                </div>
                <div
                  style={{
                    width: "100%",
                    height: "6px",
                    borderRadius: "3px",
                    background: "var(--fz-surface-3)",
                  }}
                >
                  <div
                    style={{
                      width: `${entry.pct}%`,
                      height: "100%",
                      borderRadius: "3px",
                      background: entry.color,
                      transition: "width 1s ease",
                    }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="section container">
        <div className="cta-banner fade-in-up">
          <h2
            className="text-3xl font-bold mb-4"
            style={{ position: "relative" }}
          >
            {renderFanzoneText("Start Your FANZONE Journey")}
          </h2>
          <p
            className="text-secondary mb-6"
            style={{
              maxWidth: 500,
              margin: "0 auto 24px",
              position: "relative",
            }}
          >
            Download the app, pick your team, and make your first prediction
            today.
          </p>
          <div
            className="flex gap-4 justify-center"
            style={{ position: "relative" }}
          >
            <a href="#download" className="btn btn-primary btn-lg">
              Get the App
            </a>
            <Link to="/faq" className="btn btn-outline btn-lg">
              Read FAQ <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </section>

      {/* Grid responsive overrides */}
      <style>{`
        @media (max-width: 768px) {
          .section > .container > div[style*="grid-template-columns: 1fr 1fr"] {
            grid-template-columns: 1fr !important;
          }
          .section > .container > div[style*="grid-template-columns: 1fr 1fr"] > *[style*="order: -1"] {
            order: 0 !important;
          }
        }
      `}</style>
    </div>
  );
}
