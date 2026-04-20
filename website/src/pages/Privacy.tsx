import { renderFanzoneText } from "../components/FanzoneWordmark";

export default function Privacy() {
  return (
    <div className="section container">
      <div className="legal-content fade-in-up">
        <h1
          style={{ fontSize: "2.25rem", fontWeight: 800, marginBottom: "8px" }}
        >
          Privacy Policy
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

        <p>
          {renderFanzoneText(
            'FANZONE ("we", "us", or "our") is operated by IKANISA. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use the FANZONE mobile application ("App").',
          )}
        </p>

        <h2>1. Information We Collect</h2>

        <h3>1.1 Information You Provide</h3>
        <ul>
          <li>
            <strong>Account Information:</strong> WhatsApp-enabled phone number
            used for OTP authentication.
          </li>
          <li>
            <strong>Profile Information:</strong> Display name, team
            preferences, and fan identity (anonymous handle).
          </li>
          <li>
            <strong>User-Generated Content:</strong> Predictions, pool
            participation, and community interactions.
          </li>
        </ul>

        <h3>1.2 Information Collected Automatically</h3>
        <ul>
          <li>
            <strong>Device Information:</strong> Device type, operating system
            version, and unique device identifiers.
          </li>
          <li>
            <strong>Push Notification Tokens:</strong> Firebase Cloud Messaging
            (FCM) tokens for delivering notifications.
          </li>
          <li>
            <strong>Usage Data:</strong> Core product events needed to operate
            predictions, wallets, leaderboards, and support workflows.
          </li>
          <li>
            <strong>Crash Reports:</strong> Runtime errors may be recorded in
            our Supabase-operated backend for stability, incident response, and
            release quality monitoring. We do not use a dedicated third-party
            crash-reporting SDK in the current release build.
          </li>
        </ul>

        <h3>1.3 Information We Do NOT Collect</h3>
        <ul>
          <li>
            <strong>Location Data:</strong> We do not collect, request, or
            process your geographic location.
          </li>
          <li>
            <strong>Payment Information:</strong> We do not process any payment
            data. FET tokens are earned through engagement and have no
            real-money value.
          </li>
          <li>
            <strong>Photos or Media:</strong> We do not access your camera,
            photo library, or any media files.
          </li>
          <li>
            <strong>Contacts:</strong> We do not access your address book or
            contact list.
          </li>
        </ul>

        <h2>2. How We Use Your Information</h2>
        <p>We use the information we collect to:</p>
        <ul>
          <li>Provide, operate, and maintain the App</li>
          <li>Authenticate your identity and manage your account</li>
          <li>
            Deliver push notifications about match updates, prediction results,
            and community activity
          </li>
          <li>Manage prediction pools, leaderboards, and FET token balances</li>
          <li>Analyze usage patterns to improve the App experience</li>
          <li>Monitor and fix technical issues</li>
          <li>Comply with legal obligations</li>
        </ul>

        <h2>3. Data Storage and Processing</h2>
        <p>Your data is processed and stored using:</p>
        <ul>
          <li>
            <strong>Supabase</strong> (PostgreSQL): Account data, predictions,
            wallets, and community content. Hosted in the EU.
          </li>
          <li>
            <strong>Firebase (Google Cloud):</strong> Push notification
            delivery.
          </li>
        </ul>
        <p>All data transfers use industry-standard encryption (TLS 1.2+).</p>

        <h2>4. Data Sharing</h2>
        <p>
          We do <strong>not</strong> sell, trade, or rent your personal
          information to third parties.
        </p>
        <p>We may share data with:</p>
        <ul>
          <li>
            <strong>Service Providers:</strong> Supabase and Firebase for the
            sole purpose of operating the App.
          </li>
          <li>
            <strong>Legal Requirements:</strong> When required by law, legal
            process, or government request.
          </li>
          <li>
            <strong>Safety:</strong> To protect the rights, property, or safety
            of IKANISA, our users, or the public.
          </li>
        </ul>

        <h2>5. Push Notifications</h2>
        <p>
          We use Firebase Cloud Messaging (FCM) to send push notifications. You
          can:
        </p>
        <ul>
          <li>
            Control notification categories in Settings → Notification
            Preferences
          </li>
          <li>Disable all notifications via your device's OS settings</li>
          <li>Notification tokens are deactivated when you log out</li>
        </ul>

        <h2>6. Data Retention</h2>
        <ul>
          <li>
            <strong>Active accounts:</strong> Data is retained for the lifetime
            of your account.
          </li>
          <li>
            <strong>Deleted accounts:</strong> Personal data is deleted within
            30 days of account deletion. Anonymized prediction and leaderboard
            data may be retained for statistical purposes.
          </li>
          <li>
            <strong>Device tokens:</strong> Deactivated tokens are purged after
            90 days of inactivity.
          </li>
        </ul>

        <h2>7. Your Rights (GDPR — EU Users)</h2>
        <p>
          {renderFanzoneText(
            "As FANZONE is operated from Malta (EU), you have the following rights under the General Data Protection Regulation (GDPR):",
          )}
        </p>
        <ul>
          <li>
            <strong>Access:</strong> Request a copy of your personal data
          </li>
          <li>
            <strong>Rectification:</strong> Request correction of inaccurate
            data
          </li>
          <li>
            <strong>Erasure:</strong> Request deletion of your account and
            associated data
          </li>
          <li>
            <strong>Portability:</strong> Request your data in a
            machine-readable format
          </li>
          <li>
            <strong>Objection:</strong> Object to processing of your data for
            specific purposes
          </li>
          <li>
            <strong>Restriction:</strong> Request restriction of processing in
            certain circumstances
          </li>
        </ul>
        <p>
          To exercise these rights, contact us at:{" "}
          <strong>info@ikanisa.com</strong> or use Settings → Request Account
          Deletion in the app.
        </p>

        <h2>8. Children's Privacy</h2>
        <p>
          {renderFanzoneText(
            "FANZONE is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If we discover that a child under 13 has provided us with personal information, we will delete it immediately.",
          )}
        </p>

        <h2>9. Security</h2>
        <p>
          We implement appropriate technical and organizational measures to
          protect your personal data, including:
        </p>
        <ul>
          <li>Row-Level Security (RLS) on all database tables</li>
          <li>
            Server-side authentication verification for all write operations
          </li>
          <li>Encrypted data transmission (TLS 1.2+)</li>
          <li>Regular security audits</li>
        </ul>

        <h2>10. Changes to This Privacy Policy</h2>
        <p>
          We may update this Privacy Policy from time to time. We will notify
          you of any changes by:
        </p>
        <ul>
          <li>Posting the updated policy in the App</li>
          <li>Updating the "Last updated" date at the top of this document</li>
          <li>Sending a push notification for material changes</li>
        </ul>

        <h2>11. Contact Us</h2>
        <p>
          If you have questions about this Privacy Policy or our data practices:
        </p>
        <ul>
          <li>
            <strong>Email:</strong> info@ikanisa.com
          </li>
          <li>
            <strong>General:</strong> info@ikanisa.com
          </li>
          <li>
            <strong>Address:</strong> IKANISA, Malta
          </li>
        </ul>
      </div>
    </div>
  );
}
