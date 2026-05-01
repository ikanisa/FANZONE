import React from 'react';
import {
  BarChart3,
  Coins,
  ShoppingCart,
  Building2,
  Download,
  Trophy,
} from 'lucide-react';
import { LoadingState, ErrorState, EmptyState } from '../../components/ui/StateViews';
import { useHospitalityAuditStats, useVenuePerformance } from './useHospitality';

type MetricCardProps = {
  title: string;
  value: string;
  subValue?: string;
  icon: React.ReactNode;
};

const MetricCard = ({ title, value, subValue, icon }: MetricCardProps) => (
  <div className="bg-white p-6 rounded-[24px] border border-border flex flex-col gap-4 shadow-sm">
    <div className="w-12 h-12 bg-primary/5 text-primary rounded-2xl flex items-center justify-center">
      {icon}
    </div>
    <div>
      <p className="text-xs font-bold text-textSecondary uppercase tracking-widest">{title}</p>
      <h3 className="text-3xl font-black text-text mt-1">{value}</h3>
      {subValue && <p className="text-xs text-textSecondary font-medium mt-1">{subValue}</p>}
    </div>
  </div>
);

export const HospitalityAuditPage: React.FC = () => {
  const {
    data: stats,
    isLoading: statsLoading,
    error: statsError,
    refetch: refetchStats,
  } = useHospitalityAuditStats();
  const {
    data: venues = [],
    isLoading: venuesLoading,
    error: venuesError,
    refetch: refetchVenues,
  } = useVenuePerformance();

  const loading = statsLoading || venuesLoading;
  const error = statsError || venuesError;

  return (
    <div className="space-y-8 max-w-[1600px] mx-auto">
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-4xl font-black tracking-tighter">Venues</h1>
          <p className="text-textSecondary font-medium mt-1">
            Live venue order, FET redemption, and venue-linked pool activity.
          </p>
        </div>
        <button className="flex items-center gap-2 px-6 py-3 bg-white border border-border rounded-xl font-bold hover:bg-surface2 transition-all">
          <Download size={18} />
          EXPORT VENUE LOG
        </button>
      </div>

      {loading ? (
        <LoadingState lines={8} />
      ) : error ? (
        <ErrorState
          description={error instanceof Error ? error.message : 'Could not load venue data.'}
          onRetry={() => {
            void refetchStats();
            void refetchVenues();
          }}
        />
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <MetricCard
              title="Orders"
              value={(stats?.totalOrders ?? 0).toLocaleString()}
              icon={<ShoppingCart size={24} />}
            />
            <MetricCard
              title="Gross Revenue"
              value={`€${(stats?.totalRevenueEur ?? 0).toLocaleString()}`}
              icon={<BarChart3 size={24} />}
            />
            <MetricCard
              title="FET Redeemed"
              value={(stats?.totalFetRedeemed ?? 0).toLocaleString()}
              icon={<Coins size={24} />}
            />
            <MetricCard
              title="Venue Pools"
              value={(stats?.totalStakesCreated ?? 0).toLocaleString()}
              subValue={`${(stats?.totalStakedFet ?? 0).toLocaleString()} FET pooled`}
              icon={<Trophy size={24} />}
            />
          </div>

          <div className="bg-white rounded-[32px] border border-border overflow-hidden shadow-sm">
            <div className="p-8 border-b border-border flex justify-between items-center">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-success/10 text-success rounded-xl flex items-center justify-center">
                  <Building2 size={20} />
                </div>
                <h3 className="font-black text-xl">Venue Performance</h3>
              </div>
              <span className="text-xs font-black text-textSecondary uppercase tracking-widest">
                {(stats?.activeVenuesCount ?? 0).toLocaleString()} active venues
              </span>
            </div>

            {venues.length === 0 ? (
              <div className="p-8">
                <EmptyState title="No venue activity yet" />
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left">
                  <thead>
                    <tr className="bg-surface2/50 border-b border-border">
                      <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest">Venue</th>
                      <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Orders</th>
                      <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Revenue</th>
                      <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">FET Redeemed</th>
                      <th className="px-8 py-4 text-[10px] font-black text-textSecondary uppercase tracking-widest text-right">Pools</th>
                    </tr>
                  </thead>
                  <tbody>
                    {venues.map((venue) => (
                      <tr key={venue.venueId} className="border-b border-border last:border-0 hover:bg-surface2 transition-colors">
                        <td className="px-8 py-6">
                          <p className="font-black text-text">{venue.venueName}</p>
                          <p className="text-xs text-textSecondary font-medium">{venue.venueId}</p>
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
                          <p className="font-bold text-sm">{venue.poolCount} Pools</p>
                          <p className="text-[10px] font-black text-textSecondary uppercase">
                            {venue.participantCount.toLocaleString()} participants
                          </p>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
};
