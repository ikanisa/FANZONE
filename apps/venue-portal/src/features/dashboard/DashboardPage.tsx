import React, { useState, useEffect } from 'react';
import { 
  TrendingUp, 
  Coins, 
  ShoppingCart, 
  Users, 
  Clock,
  ChevronRight
} from 'lucide-react';
import { MenuMagicModal } from '../../components/MenuMagicModal';
import type { ScannedMenuItem } from '../../hooks/useMenuMagic';
import { useVenue } from '../../hooks/useVenueContext';
import { useVenueStats } from '../../hooks/useVenueStats';
import { useOrders } from '../../hooks/useOrders';
import { useVenueStakes } from '../../hooks/useVenueStakes';
import { supabase } from '../../lib/supabase';
import type { VenueMatchStake } from '@fanzone/core';

type StatCardProps = {
  title: string;
  value: string;
  icon: React.ReactNode;
  trend: string;
  color: string;
};

type ActiveMatch = VenueMatchStake & {
  matchName: string;
};

const StatCard = ({ title, value, icon, trend, color }: StatCardProps) => (
  <div className="bg-white p-6 rounded-[24px] border border-border flex flex-col gap-4 shadow-sm">
    <div className="flex justify-between items-start">
      <div className={`w-12 h-12 rounded-2xl flex items-center justify-center ${color}`}>
        {icon}
      </div>
      <div className={`flex items-center gap-1 text-xs font-black ${trend.startsWith('+') ? 'text-success' : 'text-danger'}`}>
        {trend} <TrendingUp size={12} className={trend.startsWith('-') ? 'rotate-180' : ''} />
      </div>
    </div>
    <div>
      <p className="text-xs font-bold text-textSecondary uppercase tracking-widest">{title}</p>
      <h3 className="text-3xl font-black text-text mt-1">{value}</h3>
    </div>
  </div>
);

export const DashboardPage: React.FC = () => {
  const { venue } = useVenue();
  const { stats } = useVenueStats(venue?.id || '');
  const { orders } = useOrders(venue?.id || '');
  const { stakes } = useVenueStakes(venue?.id || '');
  const [activeMatch, setActiveMatch] = useState<ActiveMatch | null>(null);
  const [isMagicModalOpen, setIsMagicModalOpen] = useState(false);

  useEffect(() => {
    if (stakes.length > 0) {
      // Find the first open stake and fetch its match name
      const activeStake = stakes.find(s => s.status === 'open');
      if (activeStake) {
        supabase.from('matches').select('home_team, away_team').eq('id', activeStake.matchId).single().then(({ data }) => {
          if (data) {
            const homeTeam = data.home_team ?? 'Home';
            const awayTeam = data.away_team ?? 'Away';
            setActiveMatch({ ...activeStake, matchName: `${homeTeam} vs ${awayTeam}` });
          }
        });
      }
    }
  }, [stakes]);

  const handleMagicComplete = (items: ScannedMenuItem[]) => {
     console.log('Dashboard Import:', items);
     alert(`Success! Imported ${items.length} items to your drafts.`);
  };

  const currencySymbol = venue?.country === 'RW' ? '' : '€';
  const currencySuffix = venue?.country === 'RW' ? ' RWF' : '';

  return (
    <div className="space-y-8 max-w-7xl mx-auto">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Command Center</h1>
          <p className="text-textSecondary font-medium mt-1">Live overview of your venue operations.</p>
        </div>
        <div className="flex gap-2">
          <div className="px-4 py-2 bg-white border border-border rounded-xl flex items-center gap-2 text-sm font-bold">
            <div className="w-2 h-2 bg-success rounded-full animate-pulse" />
            LIVE SYSTEM
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard 
          title="Daily Revenue" 
          value={`${currencySymbol}${stats.dailyRevenue.toLocaleString()}${currencySuffix}`} 
          icon={<ShoppingCart size={24} />} 
          trend="+12%" 
          color="bg-primary/5 text-primary"
        />
        <StatCard 
          title="FET Redeemed" 
          value={stats.fetRedeemed.toLocaleString()} 
          icon={<Coins size={24} />} 
          trend="+8%" 
          color="bg-accent/10 text-success"
        />
        <StatCard 
          title="Active Orders" 
          value={stats.activeOrders.toString()} 
          icon={<Clock size={24} />} 
          trend="+4" 
          color="bg-accent2/10 text-accent2"
        />
        <StatCard 
          title="Match Guests" 
          value={stats.matchGuests.toString()} 
          icon={<Users size={24} />} 
          trend="+15" 
          color="bg-primary/5 text-primary"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-6">
          <div className="bg-white rounded-[32px] border border-border overflow-hidden shadow-sm">
            <div className="p-8 border-b border-border flex justify-between items-center">
              <h3 className="font-black text-xl">Recent Activity</h3>
              <button className="text-sm font-bold text-textSecondary flex items-center gap-1 hover:text-text">
                View All <ChevronRight size={16} />
              </button>
            </div>
            <div className="p-0">
               {orders.length === 0 ? (
                 <div className="p-12 text-center text-textSecondary font-medium">No active orders found.</div>
               ) : (
                 orders.slice(0, 5).map((order) => (
                   <div key={order.id} className="flex items-center gap-4 p-6 border-b border-border last:border-0 hover:bg-surface2 transition-colors cursor-pointer">
                      <div className="w-12 h-12 bg-surface3 rounded-xl flex items-center justify-center font-black uppercase">
                        #{order.orderCode.slice(-4)}
                      </div>
                      <div className="flex-1">
                         <p className="font-bold">Order for Table {order.tableId.slice(0, 4)}</p>
                         <p className="text-sm text-textSecondary">{order.items?.map(i => i.itemNameSnapshot).join(', ')}</p>
                      </div>
                      <div className="text-right">
                         <p className="font-black text-primary">{currencySymbol}{order.totalAmount.toLocaleString()}{currencySuffix}</p>
                         <p className="text-xs text-textSecondary">Active</p>
                      </div>
                   </div>
                 ))
               )}
            </div>
          </div>
        </div>

        <div className="space-y-6">
           <div className="bg-primary text-primaryText p-8 rounded-[32px] shadow-2xl shadow-primary/20 relative overflow-hidden group">
              <div className="relative z-10">
                <h3 className="text-2xl font-black mb-2">Menu Magic Import</h3>
                <p className="opacity-70 text-sm font-medium mb-6">Upload a photo of your physical menu and our AI will digitize it instantly.</p>
                <button 
                  onClick={() => setIsMagicModalOpen(true)}
                  className="w-full h-14 bg-accent text-primary font-black rounded-2xl hover:scale-[1.02] active:scale-95 transition-all"
                >
                   START AI IMPORT
                </button>
              </div>
              <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-accent/20 rounded-full blur-3xl group-hover:bg-accent/40 transition-all" />
           </div>

           <div className="bg-white p-8 rounded-[32px] border border-border shadow-sm">
              <h3 className="font-black text-xl mb-4">Live Match Stake</h3>
              {activeMatch ? (
                <div className="p-4 bg-surface2 rounded-2xl border border-border mb-4">
                  <div className="flex justify-between text-xs font-bold text-textSecondary uppercase tracking-widest mb-2">
                      <span>Active Now</span>
                      <span className="text-accent2">Live</span>
                  </div>
                  <p className="font-black">{activeMatch.matchName}</p>
                  <div className="mt-3 flex items-center gap-4">
                      <div>
                        <p className="text-[10px] font-bold text-textSecondary uppercase">Pool Total</p>
                        <p className="font-black text-lg text-success">{activeMatch.totalPoolFet} FET</p>
                      </div>
                      <div>
                        <p className="text-[10px] font-bold text-textSecondary uppercase">Participants</p>
                        <p className="font-black text-lg">Active</p>
                      </div>
                  </div>
                </div>
              ) : (
                <div className="p-4 bg-surface2 rounded-2xl border border-dashed border-border mb-4 text-center text-xs text-textSecondary font-bold py-8">
                  NO ACTIVE STAKES
                </div>
              )}
              <button className="w-full font-bold text-sm text-textSecondary hover:text-text transition-colors">
                Manage All Stakes
              </button>
           </div>
        </div>
      </div>

      <MenuMagicModal 
        isOpen={isMagicModalOpen}
        onClose={() => setIsMagicModalOpen(false)}
        onComplete={handleMagicComplete}
      />
    </div>
  );
};
