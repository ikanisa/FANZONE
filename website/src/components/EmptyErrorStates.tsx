import React from 'react';
import { motion } from 'motion/react';
import { AlertCircle, Search, Calendar } from 'lucide-react';

export default function EmptyErrorStates() {
  return (
    <div className="min-h-screen bg-bg p-6 lg:p-12 flex flex-col gap-12">
      
      {/* No Fixtures */}
      <StateCard 
        icon={<Calendar className="text-accent" size={48} />}
        title="No Fixtures Found"
        desc="There are no football matches scheduled for this date. Try another day."
        action="View All Matches"
      />

      {/* Network Error */}
      <StateCard 
        icon={<AlertCircle className="text-accent2" size={48} />}
        title="Connection Error"
        desc="We couldn't connect to the server. Please check your internet connection."
        action="Retry Connection"
      />

      {/* No Search Results */}
      <StateCard 
        icon={<Search className="text-muted" size={48} />}
        title="No Results Found"
        desc="We couldn't find any matches or teams matching your search."
        action="Clear Search"
      />
    </div>
  );
}

function StateCard({ icon, title, desc, action }: { icon: React.ReactNode; title: string; desc: string; action: string }) {
  return (
    <div className="bg-surface2 p-8 rounded-3xl border border-border flex flex-col items-center text-center">
      <div className="mb-6">{icon}</div>
      <h3 className="font-display text-2xl text-text tracking-widest mb-2">{title}</h3>
      <p className="text-muted text-sm max-w-xs mb-8">{desc}</p>
      <button className="bg-surface3 hover:bg-surface3/80 text-text font-bold px-6 py-3 rounded-xl transition-all border border-border">
        {action}
      </button>
    </div>
  );
}
