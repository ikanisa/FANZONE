export default function Terms() {
  return (
    <div className="section container max-w-3xl">
      <h1 className="text-4xl font-bold mb-8">Terms and Conditions</h1>
      <p className="text-secondary mb-4 text-sm">Last Updated: {new Date().toLocaleDateString()}</p>

      <div className="flex-col gap-6" style={{ lineHeight: '1.7' }}>
        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">1. Acceptance of Terms</h2>
          <p className="text-secondary">
            By downloading the FANZONE app or accessing our website, you agree to these Terms. If you disagree with any part of the terms, you must not use our service.
          </p>
        </section>

        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">2. Not a Gambling Platform</h2>
          <p className="text-secondary">
            FANZONE is a free-to-play prediction platform. Our internal ledger token (FET) possesses no fiat monetary value, cannot be purchased, and does not constitute real-money gambling. Rewards are granted purely as promotional discounts.
          </p>
        </section>

        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">3. Conduct and Account Integrity</h2>
          <p className="text-secondary">
            Accounts are limited to one per person, verified strictly via WhatsApp OTP. Any automated scripting, botting, or attempt to manipulate prediction challenges or community meters will result in immediate API termination and wallet forfeiture.
          </p>
        </section>

        <section>
          <h2 className="text-2xl font-bold mb-3 mt-8">4. Changes to Service</h2>
          <p className="text-secondary">
            We reserve the right to withdraw or amend the app, tokens, leaderboards, or redeemable products without notice. 
          </p>
        </section>
      </div>
    </div>
  );
}
