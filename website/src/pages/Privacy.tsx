export default function Privacy() {
  return (
    <div className="section container max-w-3xl">
      <h1 className="text-4xl font-bold mb-8">Privacy Policy</h1>
      <p className="text-secondary mb-4 text-sm">Last Updated: {new Date().toLocaleDateString()}</p>
      
      <div className="flex-col gap-6" style={{ lineHeight: '1.7' }}>
        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">1. Introduction</h2>
          <p className="text-secondary">
            IKANISA ("we," "our," or "us") respects your privacy. This Privacy Policy describes how we collect, use, and share your personal data when you use the FANZONE mobile application and website.
          </p>
        </section>

        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">2. Information We Collect</h2>
          <ul className="text-secondary flex-col gap-2" style={{ listStyleType: 'disc', paddingLeft: '20px' }}>
            <li><strong>Authentication Data:</strong> Phone number and WhatsApp OTP metadata (we do not collect names or emails unless explicitly provided).</li>
            <li><strong>Usage Data:</strong> Prediction history, app engagement, favorite teams, and ledger transaction history.</li>
            <li><strong>Device Info:</strong> Device tokens for Push Notifications and aggregate analytics logs.</li>
          </ul>
        </section>

        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">3. How We Use Your Data</h2>
          <p className="text-secondary">
            We use your data solely to operate the prediction platform, credit FET tokens, ensure the security of the ledger, and provide AI-curated team news.
          </p>
        </section>

        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">4. Account Deletion</h2>
          <p className="text-secondary">
            You may request deletion of your account at any time via the "Settings" tab in the app. This securely scrubs your phone identity and marks your prediction history as anonymous.
          </p>
        </section>
      </div>
    </div>
  );
}
