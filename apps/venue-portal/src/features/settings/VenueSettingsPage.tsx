import React from 'react';
import { Building2, LogOut, Settings, ShieldCheck } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useVenue } from '../../hooks/useVenueContext';
import { useVenueAuth } from '../../hooks/useVenueAuth';

export const VenueSettingsPage: React.FC = () => {
  const { venue, member } = useVenue();
  const { logout } = useVenueAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/orders', { replace: true });
  };

  return (
    <div className="space-y-8 max-w-5xl mx-auto">
      <div>
        <h1 className="text-4xl font-black tracking-tighter">Settings</h1>
        <p className="text-textSecondary font-medium mt-1">
          Venue identity, access context, and operational defaults.
        </p>
      </div>

      <div className="bg-white border border-border rounded-[28px] p-8 shadow-sm">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-primary/5 text-primary rounded-2xl flex items-center justify-center">
            <Building2 size={24} />
          </div>
          <div className="flex-1">
            <p className="text-xs font-bold text-textSecondary uppercase tracking-widest">Current Venue</p>
            <h2 className="text-2xl font-black mt-1">{venue?.name ?? 'Venue unavailable'}</h2>
            <p className="text-sm text-textSecondary mt-2">
              {venue?.address ?? 'Address not set'} · {venue?.country ?? 'Country not set'}
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white border border-border rounded-[24px] p-6 shadow-sm">
          <div className="flex items-center gap-3 mb-4">
            <Settings size={20} className="text-primary" />
            <h3 className="font-black text-xl">Operational Defaults</h3>
          </div>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between gap-4">
              <span className="text-textSecondary font-bold">Currency</span>
              <span className="font-black">{venue?.country === 'RW' ? 'RWF' : 'EUR'}</span>
            </div>
            <div className="flex justify-between gap-4">
              <span className="text-textSecondary font-bold">Status</span>
              <span className="font-black">{venue ? 'Active' : 'Unavailable'}</span>
            </div>
          </div>
        </div>

        <div className="bg-white border border-border rounded-[24px] p-6 shadow-sm">
          <div className="flex items-center gap-3 mb-4">
            <ShieldCheck size={20} className="text-success" />
            <h3 className="font-black text-xl">Access</h3>
          </div>
          <div className="space-y-3 text-sm">
            <div className="flex justify-between gap-4">
              <span className="text-textSecondary font-bold">Role</span>
              <span className="font-black capitalize">{member?.role ?? 'staff'}</span>
            </div>
            <button
              type="button"
              onClick={handleLogout}
              className="mt-4 w-full flex items-center justify-center gap-2 px-4 py-3 text-danger font-bold bg-danger/5 rounded-xl hover:bg-danger/10 transition-colors"
            >
              <LogOut size={18} />
              Logout
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
