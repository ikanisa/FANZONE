export default function FAQ() {
  const faqs = [
    {
      q: "How do I earn FET?",
      a: "FET is earned primarily by making accurate predictions on match outcomes, completing daily challenges, and participating in team community events."
    },
    {
      q: "Is FANZONE free?",
      a: "Yes. Guest browsing is completely free, and authenticated fans start with a baseline of prediction slips. No real money deposits are required."
    },
    {
      q: "Why do I need WhatsApp to login?",
      a: "We prioritize security and community integrity. WhatsApp OTP verification ensures one real human per account, preventing bot manipulation of our token ledger."
    },
    {
      q: "Where can I redeem FET?",
      a: "FET can be redeemed for exclusive deals, discounts, and merchandise at select partner locations. This catalog is continually expanding."
    }
  ];

  return (
    <div className="section container max-w-3xl">
      <div className="text-center mb-16">
        <h1 className="text-4xl font-bold mb-4">Frequently Asked Questions</h1>
      </div>
      
      <div className="flex-col gap-6">
        {faqs.map((faq, i) => (
          <div key={i} className="glass-card" style={{ padding: '24px' }}>
            <h3 className="text-xl font-bold mb-3">{faq.q}</h3>
            <p className="text-secondary">{faq.a}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
