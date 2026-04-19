import { Coins, Shield, RefreshCw } from 'lucide-react';

export default function FetToken() {
  return (
    <div className="section container">
      <div className="text-center mb-16">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">The FET Economy</h1>
        <p className="text-xl text-secondary max-w-2xl mx-auto">
          The internal ledger powering engagement, rewards, and predictions.
        </p>
      </div>

      <div className="grid md:grid-cols-3 gap-8">
        <div className="glass-card">
          <Coins size={32} className="text-accent mb-4" />
          <h3 className="text-xl font-bold mb-2">What is FET?</h3>
          <p className="text-secondary">
            FET is an internal token managed by our Supabase ledger. It represents your success on the platform, used to enter premium predictions and claim rewards.
          </p>
        </div>
        
        <div className="glass-card">
          <Shield size={32} className="text-accent mb-4" />
          <h3 className="text-xl font-bold mb-2">Strict Governance</h3>
          <p className="text-secondary">
            Supply caps and minting are tightly controlled by backend RLS and audited RPCs. Real value flows through secure, transactional verification.
          </p>
        </div>

        <div className="glass-card">
          <RefreshCw size={32} className="text-accent mb-4" />
          <h3 className="text-xl font-bold mb-2">Redemption</h3>
          <p className="text-secondary">
            Convert your FET balances at select Maltease and global fulfillment partners directly within the secure wallet interface.
          </p>
        </div>
      </div>
    </div>
  );
}
