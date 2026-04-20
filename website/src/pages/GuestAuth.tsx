import {
  Eye,
  ShieldCheck,
  CheckCircle2,
  Lock,
  ArrowRight,
  MessageCircle,
  Smartphone,
} from "lucide-react";
import { Link } from "react-router-dom";
import { renderFanzoneText } from "../components/FanzoneWordmark";

export default function GuestAuth() {
  return (
    <div>
      <div className="page-heading container">
        <h1>Privacy by Design</h1>
        <p>
          {renderFanzoneText(
            "Explore FANZONE on your terms. Browse freely as a guest, and upgrade when you're ready to play.",
          )}
        </p>
      </div>

      {/* Comparison Cards */}
      <section className="section container">
        <div
          className="grid grid-cols-2 gap-8"
          style={{ maxWidth: 900, margin: "0 auto" }}
        >
          {/* Guest Mode */}
          <div
            className="comparison-card fade-in-up"
            style={{ border: "1px solid var(--fz-border-2)" }}
          >
            <div className="flex items-center gap-3 mb-6">
              <div
                className="icon-box icon-box-sm"
                style={{ background: "var(--fz-surface-3)" }}
              >
                <Eye size={22} color="var(--fz-muted)" />
              </div>
              <h2 className="text-xl font-bold">Guest Mode</h2>
            </div>
            <p
              className="text-secondary text-sm mb-6"
              style={{ lineHeight: 1.6 }}
            >
              Download and start discovering right away. No phone number. No
              personal data shared.
            </p>
            <ul
              style={{ display: "flex", flexDirection: "column", gap: "14px" }}
            >
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-muted)" />
                <span className="text-sm">Browse live matches & fixtures</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-muted)" />
                <span className="text-sm">View live scores & standings</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-muted)" />
                <span className="text-sm">Check leaderboards</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-muted)" />
                <span className="text-sm">Browse teams & competitions</span>
              </li>
              <li className="flex items-center gap-3" style={{ opacity: 0.4 }}>
                <Lock size={18} color="var(--fz-muted)" />
                <span className="text-sm">No predictions</span>
              </li>
              <li className="flex items-center gap-3" style={{ opacity: 0.4 }}>
                <Lock size={18} color="var(--fz-muted)" />
                <span className="text-sm">No FET wallet</span>
              </li>
              <li className="flex items-center gap-3" style={{ opacity: 0.4 }}>
                <Lock size={18} color="var(--fz-muted)" />
                <span className="text-sm">No fan identity</span>
              </li>
            </ul>
          </div>

          {/* Authenticated */}
          <div
            className="comparison-card fade-in-up fade-in-up-delay-1"
            style={{ border: "1px solid var(--fz-accent)" }}
          >
            <div className="flex items-center gap-3 mb-6">
              <div
                className="icon-box icon-box-sm"
                style={{ background: "rgba(152, 255, 152, 0.1)" }}
              >
                <ShieldCheck size={22} color="var(--fz-accent)" />
              </div>
              <h2 className="text-xl font-bold">Authenticated</h2>
              <span
                style={{
                  padding: "2px 10px",
                  borderRadius: "20px",
                  background: "rgba(152, 255, 152, 0.1)",
                  color: "var(--fz-accent)",
                  fontSize: "0.6875rem",
                  fontWeight: 700,
                }}
              >
                FULL ACCESS
              </span>
            </div>
            <p
              className="text-secondary text-sm mb-6"
              style={{ lineHeight: 1.6 }}
            >
              Verify with WhatsApp OTP to unlock the complete ecosystem. One-tap
              simple — one real person per account.
            </p>
            <ul
              style={{ display: "flex", flexDirection: "column", gap: "14px" }}
            >
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">Everything in Guest mode</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">Full prediction access</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">FET wallet & transfers</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">Fan identity & communities</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">Partner rewards access</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">Push notifications</span>
              </li>
              <li className="flex items-center gap-3">
                <CheckCircle2 size={18} color="var(--fz-accent)" />
                <span className="text-sm">Pool creation & participation</span>
              </li>
            </ul>
            <Link
              to="/overview"
              className="btn btn-primary w-full mt-6"
              style={{ justifyContent: "center", marginTop: "24px" }}
            >
              See Full Product Overview
            </Link>
          </div>
        </div>
      </section>

      {/* Upgrade Path */}
      <section className="section" style={{ background: "var(--fz-surface)" }}>
        <div className="container" style={{ maxWidth: 800, margin: "0 auto" }}>
          <div className="section-header">
            <h2>Seamless Upgrade Path</h2>
            <p>
              Start as a guest and upgrade any time — your browsing data is
              preserved.
            </p>
          </div>

          <div
            style={{ display: "flex", flexDirection: "column", gap: "16px" }}
          >
            {[
              {
                step: "1",
                icon: <Smartphone size={22} color="var(--fz-accent)" />,
                title: "Download & Browse",
                desc: "Install FANZONE from the App Store or Google Play. Start browsing matches, scores, and standings immediately as a guest.",
              },
              {
                step: "2",
                icon: <MessageCircle size={22} color="var(--fz-success)" />,
                title: "Verify with WhatsApp",
                desc: 'When you\'re ready, tap "Continue with WhatsApp" to verify your identity via OTP. One phone number = one account. Zero bots.',
              },
              {
                step: "3",
                icon: <ShieldCheck size={22} color="var(--fz-coral)" />,
                title: "Full Access Unlocked",
                desc: "Your guest data (favorite teams, followed competitions) is merged to your authenticated profile. Start predicting, earning, and redeeming.",
              },
            ].map((item, i) => (
              <div
                key={i}
                className="fade-in-up"
                style={{
                  display: "flex",
                  gap: "20px",
                  padding: "24px",
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
                  {item.icon}
                </div>
                <div>
                  <div className="font-bold mb-1">
                    Step {item.step}: {item.title}
                  </div>
                  <div
                    className="text-sm text-secondary"
                    style={{ lineHeight: 1.7 }}
                  >
                    {renderFanzoneText(item.desc)}
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div style={{ textAlign: "center", marginTop: "32px" }}>
            <Link to="/faq" className="btn btn-outline">
              Read FAQ <ArrowRight size={16} />
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
