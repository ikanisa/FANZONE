interface DigitalMembershipCardProps {
  clubName: string;
  tier: string;
  fanId: string;
  crest: string;
  color: string;
  memberSince: string;
}

export function DigitalMembershipCard({ clubName, tier, fanId, crest, color, memberSince }: DigitalMembershipCardProps) {
  return (
    <div className="relative w-full max-w-md mx-auto aspect-[1.6/1] rounded-2xl overflow-hidden group">
      {/* Background with Glassmorphism */}
      <div 
        className="absolute inset-0 opacity-90"
        style={{
          background: `linear-gradient(135deg, ${color}44 0%, rgba(19,20,24,0.94) 62%, rgba(152,255,152,0.18) 100%)`,
        }}
      />
      <div className="absolute inset-0 backdrop-blur-xl bg-surface/40 border border-white/10 rounded-2xl" />
      
      {/* Decorative Elements */}
      <div 
        className="absolute -top-20 -right-20 w-48 h-48 rounded-full blur-[50px] opacity-50"
        style={{ background: color }}
      />
      <div 
        className="absolute -bottom-20 -left-20 w-48 h-48 rounded-full blur-[50px] opacity-30"
        style={{ background: 'rgba(152,255,152,0.55)' }}
      />

      {/* Content */}
      <div className="relative h-full p-6 flex flex-col justify-between z-10">
        <div className="flex justify-between items-start">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-surface/50 border border-white/20 flex items-center justify-center text-2xl shadow-inner backdrop-blur-md">
              {crest}
            </div>
            <div>
              <h3 className="font-display text-xl text-text tracking-widest leading-none">{clubName}</h3>
              <div className="text-[9px] text-text/60 uppercase tracking-widest mt-1">Official Fan Club</div>
            </div>
          </div>
          <div 
            className="px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest border"
            style={{ 
              background: `${color}20`, 
              color: color,
              borderColor: `${color}40`
            }}
          >
            {tier}
          </div>
        </div>

        <div>
          <div className="text-[10px] text-text/50 uppercase tracking-widest mb-1">Fan ID</div>
          <div className="font-mono text-2xl text-text tracking-[4px] font-bold shadow-sm">{fanId}</div>
          
          <div className="flex justify-between items-end mt-4">
            <div>
              <div className="text-[8px] text-text/50 uppercase tracking-widest mb-0.5">Member Since</div>
              <div className="font-mono text-xs text-text/80">{memberSince}</div>
            </div>
            <div className="font-display text-2xl text-text/10 tracking-widest">FANZONE</div>
          </div>
        </div>
      </div>

      {/* Shine Effect */}
      <div className="absolute inset-0 bg-gradient-to-tr from-transparent via-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-1000 transform -translate-x-full group-hover:translate-x-full" />
    </div>
  );
}
