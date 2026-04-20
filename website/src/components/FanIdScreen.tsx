import { motion } from 'motion/react';
import { ChevronLeft, Fingerprint, ShieldCheck, Copy, CheckCircle2 } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';
import { useState } from 'react';

export default function FanIdScreen() {
  const { fanId } = useAppStore();
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(fanId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="min-h-screen bg-bg pb-24">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center justify-between">
        <Link to="/profile" className="text-text hover:text-primary transition-all">
          <ChevronLeft size={24} />
        </Link>
        <div className="text-center">
          <div className="text-[10px] font-bold text-muted uppercase tracking-widest">Identity</div>
          <div className="text-sm font-bold text-text">My Fan ID</div>
        </div>
        <div className="w-6" />
      </header>

      <div className="p-6 lg:p-12 max-w-2xl mx-auto space-y-8">
        <div className="text-center mb-8">
          <h1 className="font-display text-3xl text-text tracking-widest mb-2">FAN ID SPECIFICATION</h1>
          <p className="text-muted text-sm">Your privacy-first anonymous identity.</p>
        </div>

        {/* ID Display Card */}
        <div className="bg-surface2 border border-border rounded-3xl p-6 lg:p-8 relative overflow-hidden">
          <div className="absolute top-[-50px] right-[-50px] w-32 h-32 bg-primary/10 blur-[40px] rounded-full pointer-events-none"></div>
          
          <div className="flex items-center gap-6 mb-6 relative z-10">
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-primary to-secondary flex items-center justify-center text-3xl shadow-inner flex-shrink-0">
              ⚽
            </div>
            <div className="flex-1">
              <div className="flex items-center justify-between mb-1">
                <div className="font-mono text-3xl font-bold text-text tracking-[4px]">{fanId}</div>
                <button 
                  onClick={handleCopy}
                  className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-muted hover:text-primary transition-colors"
                >
                  {copied ? <CheckCircle2 size={16} className="text-primary" /> : <Copy size={16} />}
                </button>
              </div>
              <div className="text-[10px] text-muted uppercase tracking-widest font-bold">
                Auto-assigned on first app open
              </div>
            </div>
          </div>

          <div className="flex gap-2 flex-wrap relative z-10">
            <span className="inline-flex items-center gap-1 bg-primary/10 border border-primary/20 rounded-full px-3 py-1 text-[10px] font-bold text-primary">
              <ShieldCheck size={12} /> Anonymous
            </span>
            <span className="inline-flex items-center gap-1 bg-surface3 border border-border rounded-full px-3 py-1 text-[10px] font-bold text-muted">
              No Real Name
            </span>
            <span className="inline-flex items-center gap-1 bg-surface3 border border-border rounded-full px-3 py-1 text-[10px] font-bold text-muted">
              Permanent
            </span>
          </div>
        </div>

        {/* Rules List */}
        <div className="bg-surface2 rounded-3xl border border-border overflow-hidden">
          <div className="p-6 border-b border-border bg-surface3/50">
            <h3 className="font-display text-xl text-text tracking-widest">IDENTITY RULES</h3>
          </div>
          <ul className="p-6 grid grid-cols-1 md:grid-cols-2 gap-4">
            <RuleItem text="6-digit numeric ID — unique per device/session" />
            <RuleItem text="Stored securely as your primary identifier" />
            <RuleItem text="Displayed as '#XXX XXX' format throughout app" />
            <RuleItem text="Auto-generated avatar assigned to your ID" />
            <RuleItem text="No real name displayed anywhere in public UI" />
            <RuleItem text="No phone number visible to other users ever" />
            <RuleItem text="No WhatsApp number exposed — server-side only" />
            <RuleItem text="Leaderboards show Fan ID + avatar only" />
            <RuleItem text="Membership shows Fan ID + tier badge only" />
            <RuleItem text="MoMo contributions anonymous by Fan ID only" />
            <RuleItem text="Fan ID persists post-WA auth — same ID retained" />
            <RuleItem text="User can set a custom display nickname (post-auth)" />
          </ul>
        </div>
      </div>
    </div>
  );
}

function RuleItem({ text }: { text: string }) {
  return (
    <li className="flex items-start gap-3 text-xs text-text">
      <Fingerprint size={14} className="text-primary shrink-0 mt-[2px]" />
      <span className="leading-relaxed">{text}</span>
    </li>
  );
}
