import { Gift, CreditCard, Tag } from 'lucide-react';

export default function Rewards() {
  return (
    <div className="section container">
      <div className="text-center mb-16">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">Partner Rewards</h1>
        <p className="text-xl text-secondary max-w-2xl mx-auto">
          Convert your football IQ into real-world value through our exclusive retail partnerships.
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-8 my-16">
        <div className="glass-card flex-col justify-center items-center text-center">
          <Gift size={48} className="text-red mb-6" />
          <h2 className="text-2xl font-bold mb-4">1. Earn FET</h2>
          <p className="text-secondary">Climb leaderboards, hit daily challenges, and grow your token balance transparently on our verifiable ledger.</p>
        </div>
        
        <div className="glass-card flex-col justify-center items-center text-center">
          <Tag size={48} className="text-amber mb-6" />
          <h2 className="text-2xl font-bold mb-4">2. Browse Marketplace</h2>
          <p className="text-secondary">Discover exclusive discounts, merchandise, and retail offers hosted directly in the FANZONE app.</p>
        </div>
        
        <div className="glass-card flex-col justify-center items-center text-center">
          <CreditCard size={48} className="text-success mb-6" />
          <h2 className="text-2xl font-bold mb-4">3. Redeem</h2>
          <p className="text-secondary">Scan securely at partner locations or use your designated secure token link to finalize your redemption.</p>
        </div>
      </div>
    </div>
  );
}
