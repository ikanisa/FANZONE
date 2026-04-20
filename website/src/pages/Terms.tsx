import { renderFanzoneText } from "../components/FanzoneWordmark";

export default function Terms() {
  return (
    <div className="section container">
      <div className="legal-content fade-in-up">
        <h1
          style={{ fontSize: "2.25rem", fontWeight: 800, marginBottom: "8px" }}
        >
          Terms and Conditions
        </h1>
        <p
          style={{
            color: "var(--fz-muted)",
            fontSize: "0.875rem",
            marginBottom: "32px",
          }}
        >
          Last updated: April 18, 2026
        </p>

        <h2>1. Acceptance of Terms</h2>
        <p>
          {renderFanzoneText(
            'By downloading, accessing, or using the FANZONE mobile application ("App") or visiting our website at fanzone.ikanisa.com, you agree to be bound by these Terms and Conditions. If you disagree with any part of these terms, you must not use our service.',
          )}
        </p>

        <h2>2. Service Description</h2>
        <p>
          {renderFanzoneText(
            "FANZONE is a mobile-first football fan engagement platform operated by IKANISA from Malta. The service provides live match tracking, score predictions, fan community features, leaderboards, and an internal engagement token economy (FET). The App is available on iOS and Android.",
          )}
        </p>

        <h2>3. Eligibility</h2>
        <p>
          {renderFanzoneText(
            "You must be at least 13 years old to use FANZONE. By using the App, you represent that you meet this age requirement. Users under 18 should review these terms with a parent or guardian.",
          )}
        </p>

        <h2>4. Not a Gambling Platform</h2>
        <p>
          {renderFanzoneText("FANZONE is a ")}
          <strong>free-to-play prediction platform</strong>. Our internal ledger
          token (FET — Fan Engagement Token) possesses no fiat monetary value,
          cannot be purchased with real money, and does not constitute
          real-money gambling.
        </p>
        <p>
          FET tokens are earned exclusively through platform engagement
          (predictions, challenges, community participation) and may be redeemed
          for promotional discounts and rewards at partner locations. No real
          money is wagered, deposited, or withdrawn at any point.
        </p>

        <h2>5. Account Registration and Authentication</h2>
        <p>
          {renderFanzoneText(
            "FANZONE uses WhatsApp OTP exclusively for user authentication. By registering, you agree that:",
          )}
        </p>
        <ul>
          <li>You will provide a valid WhatsApp-enabled phone number</li>
          <li>You are limited to one account per phone number</li>
          <li>
            You will not create accounts for others or share your account
            credentials
          </li>
          <li>
            Guest browsing is available without registration for limited
            read-only access
          </li>
        </ul>

        <h2>6. FET Token Economy</h2>
        <p>
          The FET (Fan Engagement Token) system is governed by the following
          rules:
        </p>
        <ul>
          <li>
            FET tokens have no fiat monetary value and cannot be sold, traded,
            or exchanged for real currency
          </li>
          <li>
            Total FET supply is capped at 100,000,000 tokens, enforced at the
            database level
          </li>
          <li>
            FET can be earned through predictions, daily challenges, and welcome
            grants
          </li>
          <li>
            FET can be redeemed for promotional offers at partner locations
          </li>
          <li>FET can be staked in prediction pools with other users</li>
          <li>FET can be transferred between users within the platform</li>
          <li>
            IKANISA reserves the right to adjust tokenomics, earning rates, and
            redemption terms
          </li>
        </ul>

        <h2>7. Conduct and Account Integrity</h2>
        <p>You agree not to:</p>
        <ul>
          <li>
            Use automated scripts, bots, or other tools to interact with the
            platform
          </li>
          <li>Create multiple accounts or impersonate other users</li>
          <li>
            Attempt to manipulate prediction challenges, pools, or community
            meters
          </li>
          <li>Exploit bugs or vulnerabilities in the platform</li>
          <li>Post or share content that is illegal, harmful, or offensive</li>
        </ul>
        <p>
          Violations will result in immediate account termination and forfeiture
          of all FET balance.
        </p>

        <h2>8. Intellectual Property</h2>
        <p>
          {renderFanzoneText(
            "FANZONE, its logo, design, content, and underlying technology are the intellectual property of IKANISA. You may not reproduce, distribute, or create derivative works based on our service without written permission.",
          )}
        </p>
        <p>
          Football match data, team names, competition names, and related
          trademarks belong to their respective owners and are used under fair
          use for fan engagement purposes.
        </p>

        <h2>9. Privacy</h2>
        <p>
          {renderFanzoneText("Your use of FANZONE is also governed by our ")}
          <a
            href="/privacy"
            style={{
              color: "var(--fz-accent)",
              textDecoration: "underline",
              textUnderlineOffset: "2px",
            }}
          >
            Privacy Policy
          </a>
          , which details how we collect, use, and protect your information.
        </p>

        <h2>10. Limitation of Liability</h2>
        <p>
          {renderFanzoneText(
            'FANZONE is provided "as is" and "as available" without warranties of any kind. IKANISA shall not be liable for:',
          )}
        </p>
        <ul>
          <li>Interruptions or errors in the service</li>
          <li>Loss of FET tokens due to system issues or account violations</li>
          <li>Accuracy of match data, odds, or prediction outcomes</li>
          <li>Actions of other users or third-party partners</li>
          <li>Indirect, incidental, or consequential damages</li>
        </ul>

        <h2>11. Changes to Service</h2>
        <p>
          We reserve the right to modify, suspend, or discontinue any aspect of
          the App — including tokens, leaderboards, prediction mechanics,
          partner offers, or redeemable products — at any time without prior
          notice.
        </p>

        <h2>12. Governing Law</h2>
        <p>
          {renderFanzoneText(
            "These Terms are governed by the laws of Malta. Any disputes arising from the use of FANZONE shall be resolved under the jurisdiction of Maltese courts.",
          )}
        </p>

        <h2>13. Contact</h2>
        <p>If you have questions about these Terms:</p>
        <ul>
          <li>
            <strong>Email:</strong> info@ikanisa.com
          </li>
          <li>
            <strong>Privacy inquiries:</strong> info@ikanisa.com
          </li>
          <li>
            <strong>Address:</strong> IKANISA, Malta
          </li>
        </ul>
      </div>
    </div>
  );
}
