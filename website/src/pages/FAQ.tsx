import { useState } from "react";
import { ChevronDown, ArrowRight } from "lucide-react";
import { Link } from "react-router-dom";
import { renderFanzoneText } from "../components/FanzoneWordmark";

const FAQS = [
  {
    q: "What is FANZONE?",
    a: "FANZONE is a mobile-first football fan engagement platform. It combines live match tracking, score predictions, a community-driven team identity system, and an internal token economy (FET). It is designed for real football fans who want to engage more deeply with the sport.",
  },
  {
    q: "Is FANZONE a gambling platform?",
    a: "No. FANZONE is a free-to-play prediction platform. FET (Fan Engagement Tokens) are internal engagement tokens that have no fiat monetary value, cannot be purchased with real money, and do not constitute gambling. Rewards are granted as promotional discounts through partner agreements.",
  },
  {
    q: "How do I earn FET?",
    a: "FET is earned through engagement: making accurate predictions on match outcomes, completing daily challenges, achieving exact-score bonuses, and participating in community events. Every new authenticated user also receives a one-time welcome grant of 5,000 FET.",
  },
  {
    q: "Is FANZONE free?",
    a: "Yes. The app is completely free to download and use. Guest browsing requires no registration at all. Authenticated fans start with free prediction slips and a welcome FET grant. No real money deposits are required at any point.",
  },
  {
    q: "Why do I need WhatsApp to sign up?",
    a: "FANZONE uses WhatsApp OTP exclusively for authentication to ensure one real person per account. This prevents bot abuse, multi-accounting, and manipulation of the prediction ledger. It is a deliberate security and community integrity decision.",
  },
  {
    q: "What can I do as a guest?",
    a: "Guest users can browse live matches, fixtures, standings, team profiles, competition schedules, and leaderboards. However, making predictions, accessing the FET wallet, joining pools, using fan identity features, and purchasing from the rewards marketplace require full authentication.",
  },
  {
    q: "How do I upgrade from guest to authenticated?",
    a: "Tap the upgrade prompt shown when you try to access a protected feature, or navigate to the upgrade screen from settings. You will verify via WhatsApp OTP. Your guest data — including favorite teams and followed competitions — is automatically merged to your new authenticated profile.",
  },
  {
    q: "Where can I redeem FET tokens?",
    a: "FET can be redeemed at select partner locations for exclusive deals, discounts, merchandise, and digital vouchers. The partner catalog is accessible directly within the FANZONE app and is expanding globally.",
  },
  {
    q: "Which leagues and competitions are covered?",
    a: "FANZONE focuses on Europe's top-flight leagues: Premier League, La Liga, Serie A, Bundesliga, and Ligue 1, plus UEFA Champions League, Europa League, and seasonal tournaments like the World Cup and European Championships. Coverage expands based on community demand.",
  },
  {
    q: "How does FANZONE protect my privacy?",
    a: "FANZONE collects only your phone number for authentication, device tokens for push notifications, and essential usage data. We do not collect your location, photos, contacts, or payment information. All data is processed in the EU with GDPR compliance. You can request complete account deletion at any time via Settings.",
  },
  {
    q: "Can I delete my account?",
    a: "Yes. Navigate to Settings → Request Account Deletion in the app. Your personal data is deleted within 30 days. Anonymized prediction and leaderboard data may be retained for statistical purposes. You can also email info@ikanisa.com to exercise your GDPR rights.",
  },
  {
    q: "What technology powers FANZONE?",
    a: "FANZONE is built with Flutter for the mobile app, React for the admin console, and Supabase (PostgreSQL) for the backend with Row-Level Security. Sports data is ingested and processed using Google Gemini AI for reliability. Push notifications use Firebase Cloud Messaging.",
  },
];

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const toggle = (i: number) => {
    setOpenIndex(openIndex === i ? null : i);
  };

  return (
    <div>
      <div className="page-heading container">
        <h1>Frequently Asked Questions</h1>
        <p>
          {renderFanzoneText(
            "Everything you need to know about FANZONE, FET tokens, predictions, and your account.",
          )}
        </p>
      </div>

      <section className="section container">
        <div
          style={{
            maxWidth: 800,
            margin: "0 auto",
            display: "flex",
            flexDirection: "column",
            gap: "8px",
          }}
        >
          {FAQS.map((faq, i) => (
            <div
              key={i}
              className={`faq-item fade-in-up ${openIndex === i ? "open" : ""}`}
              style={{ animationDelay: `${Math.min(i * 0.03, 0.3)}s` }}
            >
              <button
                className="faq-question"
                onClick={() => toggle(i)}
                aria-expanded={openIndex === i}
                id={`faq-q-${i}`}
              >
                <span>{renderFanzoneText(faq.q)}</span>
                <ChevronDown size={18} className="faq-chevron" />
              </button>
              <div className="faq-answer">
                <p>{renderFanzoneText(faq.a)}</p>
              </div>
            </div>
          ))}
        </div>

        <div style={{ textAlign: "center", marginTop: "40px" }}>
          <p className="text-secondary mb-4">
            Can't find what you're looking for?
          </p>
          <div className="flex gap-4 justify-center">
            <Link to="/contact" className="btn btn-primary">
              Contact Support <ArrowRight size={16} />
            </Link>
            <Link to="/privacy" className="btn btn-outline">
              Privacy Policy
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
