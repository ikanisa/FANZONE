import React from 'react';
import { 
  BarChart3, 
  Coins, 
  ShoppingCart, 
  Building2, 
  ArrowUpRight, 
  ArrowDownRight,
  Search,
  Filter,
  Download,
  History,
  Trophy
} from 'lucide-react';
import type { HospitalityAuditStats, VenuePerformance } from '@fanzone/core';

// Mock Data
const MOCK_STATS: HospitalityAuditStats = {
  totalOrders: 12450,
  totalRevenueEur: 248900.50,
  totalFetRedeemed: 450000,
  totalStakesCreated: 1200,
  totalStakedFet: 850000,
  activeVenuesCount: 42
};

const MOCK_PERFORMANCE: VenuePerformance[] = [
  { venueId: 'v1', venueName: 'Stadium Sports Bar', orderCount: 450, revenueEur: 8500.50, fetRedeemed: 15000, stakeCount: 24, participantCount: 1200 },
  { venueId: 'v2', venueName: 'The Gooners Pub', orderCount: 380, revenueEur: 7200.00, fetRedeemed: 12000, stakeCount: 20, participantCount: 950 },
  { venueId: 'v3', venueName: 'Malta Fan Zone', orderCount: 310, revenueEur: 6100.25, fetRedeemed: 10500, stakeCount: 18, participantCount: 820 },
];

type MetricCardProps = {
  title: string;
  value: string;
  subValue?: string;
  icon: React.ReactNode;
  trend?: string;
};

const MetricCard = ({ title, value, subValue, icon, trend }: MetricCardProps) => (
  <div className="bg-white p-6 rounded-[24px] border border-border flex flex-col gap-4 shadow-sm">
    <div className="flex justify-between items-start">
      <div className="w-12 h-12 bg-primary/5 text-primary rounded-2xl flex items-center justify-center">
        {icon}
      </div>
      {trend && (
        <div className={`flex items-center gap-1 text-xs font-black ${trend.startsWith('+') ? 'text-success' : 'text-danger'}`}>
          {trend} {trend.startsWith('+') ? <ArrowUpRight size={14} /> : <ArrowDownRight size={14} />}
        </div>
      )}
    </div>
    <div>
      <p className="text-xs font-bold text-textSecondary uppercase tracking-widest">{title}</p>
      <h3 className="text-3xl font-black text-text mt-1">{value}</h3>
      {subValue && <p className="text-xs text-textSecondary font-medium mt-1">{subValue}</p>}
    </div>
  </div>
);

export const HospitalityAuditPage: React.FC = () => {
  return (
    <div className="space-y-8 max-w-[1600px] mx-auto">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Hospitality Auditor</h1>
          <p className="text-textSecondary font-medium mt-1">Global visibility of the FANZONE circular economy.</p>
        </div>
        <div className="flex gap-3">
          <button className="flex items-center gap-2 px-6 py-3 bg-white border border-border rounded-xl font-bold hover:bg-surface2 transition-all">
            <Download size={18} />
            EXPORT MASTER LOG
          </button>
        </div>
      </div>

      {/* Global Performance Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <MetricCard 
          title="Total Ecosystem Orders" 
          value={MOCK_STATS.totalOrders.toLocaleString()} 
          icon={<ShoppingCart size={24} />} 
          trend="+15.4%" 
        />
        <MetricCard 
          title="Total Gross Revenue" 
          value={`€${MOCK_STATS.totalRevenueEur.toLocaleString()}`} 
          icon={<BarChart3 size={24} />} 
          trend="+8.2%" 
        />
        <MetricCard 
          title="Total Tokens Redeemed" 
          value={MOCK_STATS.totalFetRedeemed.toLocaleString()} 
          subValue={`Value: €${(MOCK_STATS.totalFetRedeemed / 100).toLocaleString()}`}
          icon={<Coins size={24} />} 
          trend="+22.1%" 
        />
        <MetricCard 
          title="Match Stake Volume" 
          value={MOCK_STATS.totalStakedFet.toLocaleString()} 
          subValue={`${MOCK_STATS.totalStakesCreated} Active Pools`}
          icon={<Trophy size={24} />} 
          trend="+12.5%" 
        />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8">
        {/* Venue Performance Leaderboard */}
        <div className="xl:col-span-2 space-y-6">
          <div className="bg-white rounded-[32px] border border-border overflow-hidden shadow-sm">
            <div className="p-8 border-b border-border flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-success/10 text-success rounded-xl flex items-center justify-center">
                  <Building2 size={20} />
                </div>
                <h3 className="font-black text-xl">Venue Leaderboard</h3>
              </div>
              <div className="flex items-center gap-4">
                 <div className="relative">
                    <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-textSecondary" />
                    <input 
                      type="text" 
                      placeholder="Filter venues..." 
                      className="pl-10 pr-4 py-2 bg-surface2 border-transparent rounded-lg text-sm focus:bg-white focus:border-border outline-none transition-all"
                    />
                 </div>
                 <button className="p-2 bg-surface2 rounded-lg text-textSecondary hover:text-text"><Filter size={18} /></button>
              </div>
            </div>
            <div className="overflow-x-auto">
               <table className="w-full text-left">
                  <thead>
                     <tr className="bg-surface2/50 border-b border-border">
                        <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest">Venue</th>
                        <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Orders</th>
                        <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Revenue</th>
                        <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">FET Redeemed</th>
                        <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Engagement</th>
                     </tr>
                  </thead>
                  <tbody>
                     {MOCK_PERFORMANCE.map((venue) => (
                       <tr key={venue.venueId} className="border-b border-border last:border-0 hover:bg-surface2 transition-colors cursor-pointer group">
                          <td className="px-8 py-6">
                             <p className="font-black text-text group-hover:text-primary transition-colors">{venue.venueName}</p>
                             <p className="text-xs text-textSecondary font-medium">Malta • {venue.venueId}</p>
                          </td>
                          <td className="px-8 py-6 text-right font-bold text-sm">{venue.orderCount}</td>
                          <td className="px-8 py-6 text-right font-black text-sm">€{venue.revenueEur.toLocaleString()}</td>
                          <td className="px-8 py-6 text-right">
                             <div className="flex items-center justify-end gap-2">
                                <span className="font-black text-success text-sm">{venue.fetRedeemed.toLocaleString()}</span>
                                <Coins size={14} className="text-success" />
                             </div>
                          </td>
                          <td className="px-8 py-6 text-right">
                             <p className="font-bold text-sm">{venue.participantCount} Guests</p>
                             <p className="text-[10px] font-black text-textSecondary uppercase">{venue.stakeCount} Pools</p>
                          </td>
                       </tr>
                     ))}
                  </tbody>
               </table>
            </div>
          </div>
        </div>

        {/* Audit Log / Circular Tracing */}
        <div className="space-y-6">
           <div className="bg-primary text-primaryText p-8 rounded-[32px] shadow-2xl shadow-primary/20">
              <h3 className="text-2xl font-black mb-4">Circular Audit</h3>
              <p className="opacity-70 text-sm font-medium mb-6 leading-relaxed">
                Every token redemption is verified against a specific match pool win to prevent platform-wide fraud.
              </p>
              <div className="space-y-4">
                 <div className="p-4 bg-white/10 rounded-2xl border border-white/10">
                    <p className="text-[10px] font-bold opacity-60 uppercase tracking-widest mb-1">Last Verification</p>
                    <p className="font-black text-sm text-accent">ALL TRANSACTIONS SECURE</p>
                 </div>
              </div>
           </div>

           <div className="bg-white p-8 rounded-[32px] border border-border shadow-sm">
              <div className="flex items-center justify-between mb-6">
                <h3 className="font-black text-xl">Recent Trace</h3>
                <History size={18} className="text-textSecondary" />
              </div>
              <div className="space-y-6">
                 {[1, 2, 3].map((i) => (
                   <div key={i} className="flex gap-4 items-start">
                      <div className="w-1.5 h-1.5 bg-accent rounded-full mt-2" />
                      <div>
                         <p className="text-sm font-bold">Token Swap: Order #A102</p>
                         <p className="text-xs text-textSecondary leading-relaxed mt-1">
                           Trace: <span className="font-bold text-text">500 FET</span> redeemed from <span className="font-bold text-text">Real vs City</span> pool win.
                         </p>
                         <p className="text-[10px] font-bold text-textSecondary mt-2 uppercase tracking-tight">4 mins ago • Stadium Bar</p>
                      </div>
                   </div>
                 ))}
              </div>
              <button className="w-full mt-8 py-3 bg-surface2 text-text font-bold text-sm rounded-xl hover:bg-surface3 transition-colors">
                 VIEW FULL TRACE LOG
              </button>
           </div>
        </div>
      </div>
    </div>
  );
};
