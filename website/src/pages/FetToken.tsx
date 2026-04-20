import {
  Coins,
  Shield,
  RefreshCw,
  TrendingUp,
  Lock,
  Gift,
  ArrowRight,
} from "lucide-react";
import { Link } from "react-router-dom";
import { renderFanzoneText } from "../components/FanzoneWordmark";

export default function FetToken() {
  return (
    <div>
      <div className="page-heading container">
        <h1>The FET Economy</h1>
        <p>
          {renderFanzoneText(
            "FET (Fan Engagement Token) is the internal ledger powering predictions, rewards, and fan engagement on FANZONE.",
          )}
        </p>
      </div>

      {/* What is FET */}
      <section className="section container">
        <div
          className="grid grid-cols-3 gap-6"
          style={{ maxWidth: 1000, margin: "0 auto" }}
        >
          <div
            className="glass-card fade-in-up"
            style={{ display: "flex", flexDirection: "column", gap: "16px" }}
          >
            <div
              className="icon-box"
              style={{ background: "rgba(152, 255, 152, 0.1)" }}
            >
              <Coins size={28} color="var(--fz-accent)" />
            </div>
            <h3 className="text-lg font-bold">What is FET?</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              {renderFanzoneText(
                "FET is an internal engagement token managed by FANZONE's secure Supabase ledger. It represents your success and participation on the platform, used to enter prediction pools and claim partner rewards.",
              )}
            </p>
          </div>

          <div
            className="glass-card fade-in-up fade-in-up-delay-1"
            style={{ display: "flex", flexDirection: "column", gap: "16px" }}
          >
            <div
              className="icon-box"
              style={{ background: "rgba(152, 255, 152, 0.08)" }}
            >
              <Shield size={28} color="var(--fz-success)" />
            </div>
            <h3 className="text-lg font-bold">Strict Governance</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              Supply is capped at 100,000,000 FET. All minting is enforced by
              audited RPCs with Row-Level Security. No tokens can be created
              outside approved paths and every transaction is recorded
              immutably.
            </p>
          </div>

          <div
            className="glass-card fade-in-up fade-in-up-delay-2"
            style={{ display: "flex", flexDirection: "column", gap: "16px" }}
          >
            <div
              className="icon-box"
              style={{ background: "rgba(255, 127, 80, 0.1)" }}
            >
              <RefreshCw size={28} color="var(--fz-coral)" />
            </div>
            <h3 className="text-lg font-bold">Redemption</h3>
            <p className="text-secondary text-sm" style={{ lineHeight: 1.7 }}>
              Convert your FET balance into real-world value at select partner
              locations worldwide. Deals include exclusive discounts,
              merchandise, and in-store offers — accessible directly in the app.
            </p>
          </div>
        </div>
      </section>

      {/* How to Earn */}
      <section className="section" style={{ background: "var(--fz-surface)" }}>
        <div className="container" style={{ maxWidth: 900, margin: "0 auto" }}>
          <div className="section-header">
            <h2>How to Earn FET</h2>
            <p>
              Multiple paths to grow your balance — all based on skill and
              engagement, never money.
            </p>
          </div>

          <div
            style={{ display: "flex", flexDirection: "column", gap: "12px" }}
          >
            {[
              {
                icon: <Gift size={22} color="var(--fz-accent)" />,
                title: "Welcome Grant",
                desc: "Every new authenticated user receives a one-time grant of 5,000 FET to start their journey.",
                amount: "+5,000 FET",
              },
              {
                icon: <TrendingUp size={22} color="var(--fz-success)" />,
                title: "Correct Predictions",
                desc: "Free prediction slips reward accurate match outcome predictions with FET tokens.",
                amount: "Variable",
              },
              {
                icon: <Coins size={22} color="var(--fz-coral)" />,
                title: "Daily Challenges",
                desc: "Complete daily prediction challenges for bonus FET, including exact-score bonuses.",
                amount: "Daily Bonus",
              },
              {
                icon: <Lock size={22} color="var(--fz-blue)" />,
                title: "Pool Winnings",
                desc: "Join prediction pools with friends. Stake FET and win the entire pot if your prediction is correct.",
                amount: "Pool Pot",
              },
            ].map((path, i) => (
              <div
                key={i}
                className="fade-in-up"
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "20px",
                  padding: "20px 24px",
                  background: "var(--fz-surface-2)",
                  borderRadius: "16px",
                  border: "1px solid var(--fz-border)",
                  animationDelay: `${i * 0.1}s`,
                }}
              >
                <div
                  className="icon-box icon-box-sm"
                  style={{ background: "var(--fz-surface-3)" }}
                >
                  {path.icon}
                </div>
                <div style={{ flex: 1 }}>
                  <div className="font-bold mb-1">{path.title}</div>
                  <div className="text-sm text-secondary">{path.desc}</div>
                </div>
                <div
                  style={{
                    padding: "6px 14px",
                    borderRadius: "20px",
                    background: "rgba(152, 255, 152, 0.08)",
                    color: "var(--fz-success)",
                    fontSize: "0.75rem",
                    fontWeight: 700,
                    whiteSpace: "nowrap",
                  }}
                >
                  {path.amount}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Important Disclaimer */}
      <section className="section container">
        <div
          className="glass-card-static fade-in-up"
          style={{
            maxWidth: 800,
            margin: "0 auto",
            textAlign: "center",
            padding: "40px",
            border: "1px solid var(--fz-border-2)",
          }}
        >
          <h3 className="text-2xl font-bold mb-4">Important Information</h3>
          <p
            className="text-secondary mb-4"
            style={{ lineHeight: 1.7, maxWidth: 600, margin: "0 auto 16px" }}
          >
            {renderFanzoneText("FANZONE is a ")}
            <strong style={{ color: "var(--fz-text)" }}>
              free-to-play prediction platform
            </strong>
            . FET tokens are an internal engagement currency with{" "}
            <strong style={{ color: "var(--fz-text)" }}>
              no fiat monetary value
            </strong>
            . Tokens cannot be purchased with real money and do not constitute
            gambling.
          </p>
          <p
            className="text-secondary text-sm"
            style={{ lineHeight: 1.7, maxWidth: 600, margin: "0 auto 24px" }}
          >
            Rewards are granted as promotional discounts through partner
            agreements. The total supply of FET is hard-capped at 100,000,000
            tokens and enforced at the database level.
          </p>
          <div className="flex gap-4 justify-center">
            <Link to="/rewards" className="btn btn-outline">
              Partner Rewards <ArrowRight size={16} />
            </Link>
            <Link to="/terms" className="btn btn-ghost">
              Read Terms
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
