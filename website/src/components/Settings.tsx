import React, { useEffect } from 'react';
import { motion } from 'motion/react';
import { ChevronLeft, Bell, Globe, Moon, Sun, HelpCircle, ShieldAlert, Bug } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAppStore } from '../store/useAppStore';

export default function Settings() {
  const { addNotification, theme, toggleTheme } = useAppStore();

  const handleTestPoolReceived = () => {
    addNotification({
      type: 'pool_received',
      title: 'New Friend Pool!',
      message: 'User 582910 has poold you to predict the LIV vs ARS match. Tap to accept.',
    });
  };

  const handleTestPoolSettled = () => {
    addNotification({
      type: 'pool_settled',
      title: 'Pool Settled',
      message: 'You won the pool against User 582910! +50 FET has been added to your wallet.',
    });
  };

  return (
    <div className="min-h-screen bg-bg pb-24 transition-colors duration-300">
      {/* Header */}
      <header className="sticky top-0 z-30 bg-surface/80 backdrop-blur-md border-b border-border p-4 flex items-center gap-4">
        <Link to="/profile" className="text-text hover:text-accent transition-all w-10 h-10 rounded-full bg-surface2 border border-border flex items-center justify-center">
          <ChevronLeft size={20} />
        </Link>
        <h1 className="font-display text-2xl text-text tracking-tight">Settings</h1>
      </header>

      <div className="p-4 space-y-6">
        <SettingsSection title="Preferences">
          <div 
            className="flex items-center justify-between p-3 border-b border-border last:border-0 cursor-pointer hover:bg-surface3 transition-colors"
            onClick={toggleTheme}
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-muted">{theme === 'dark' ? <Moon size={16} /> : <Sun size={16} />}</div>
              <span className="font-bold text-sm text-text">Dark Mode</span>
            </div>
            <label className="relative inline-flex items-center cursor-pointer pointer-events-none">
              <input type="checkbox" className="sr-only peer" checked={theme === 'dark'} readOnly />
              <div className="w-9 h-5 bg-surface3 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-accent"></div>
            </label>
          </div>
          <SettingsSelect icon={<Globe size={16} />} label="Odds Format" options={['Decimal (1.85)', 'Fractional (17/20)', 'American (-118)']} />
        </SettingsSection>

        <SettingsSection title="Notifications">
          <SettingsToggle icon={<Bell size={16} />} label="Match Alerts" defaultChecked={true} />
          <SettingsToggle icon={<ShieldAlert size={16} />} label="Pool Settlement" defaultChecked={true} />
          <SettingsToggle icon={<Bell size={16} />} label="Friend Pools" defaultChecked={false} />
        </SettingsSection>

        <SettingsSection title="Developer">
          <button 
            onClick={handleTestPoolReceived}
            className="w-full flex items-center justify-between p-3 border-b border-border hover:bg-surface3 transition-colors text-left"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-accent/10 border border-accent/20 flex items-center justify-center text-accent"><Bug size={16} /></div>
              <div>
                <span className="font-bold text-sm text-text block leading-tight">Test: Pool Received</span>
              </div>
            </div>
          </button>
          <button 
            onClick={handleTestPoolSettled}
            className="w-full flex items-center justify-between p-3 hover:bg-surface3 transition-colors text-left"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-accent3/10 border border-accent3/20 flex items-center justify-center text-accent3"><Bug size={16} /></div>
              <div>
                <span className="font-bold text-sm text-text block leading-tight">Test: Pool Settled</span>
              </div>
            </div>
          </button>
        </SettingsSection>

        <SettingsSection title="Support">
          <SettingsLink icon={<HelpCircle size={16} />} label="Help & FAQ" />
          <SettingsLink icon={<ShieldAlert size={16} />} label="Privacy Policy" />
          <SettingsLink icon={<ShieldAlert size={16} />} label="Terms of Service" />
        </SettingsSection>
      </div>
    </div>
  );
}

function SettingsSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h3 className="font-sans font-bold text-sm text-text mb-2 px-1">{title}</h3>
      <div className="bg-surface2 rounded-2xl border border-border overflow-hidden">
        {children}
      </div>
    </section>
  );
}

function SettingsToggle({ icon, label, defaultChecked }: { icon: React.ReactNode; label: string; defaultChecked: boolean }) {
  return (
    <div className="flex items-center justify-between p-3 border-b border-border last:border-0 hover:bg-surface3 transition-colors cursor-pointer">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-muted">{icon}</div>
        <span className="font-bold text-sm text-text">{label}</span>
      </div>
      <label className="relative inline-flex items-center cursor-pointer pointer-events-none">
        <input type="checkbox" className="sr-only peer" defaultChecked={defaultChecked} />
        <div className="w-9 h-5 bg-surface3 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-accent"></div>
      </label>
    </div>
  );
}

function SettingsSelect({ icon, label, options }: { icon: React.ReactNode; label: string; options: string[] }) {
  return (
    <div className="flex items-center justify-between p-3 border-b border-border last:border-0">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-muted">{icon}</div>
        <span className="font-bold text-sm text-text">{label}</span>
      </div>
      <select className="bg-surface3 border border-border text-text text-[10px] font-bold rounded-lg focus:ring-accent focus:border-accent block p-1.5 outline-none">
        {options.map(opt => <option key={opt}>{opt}</option>)}
      </select>
    </div>
  );
}

function SettingsLink({ icon, label }: { icon: React.ReactNode; label: string }) {
  return (
    <button className="w-full flex items-center justify-between p-3 border-b border-border last:border-0 hover:bg-surface3 transition-colors">
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-surface3 flex items-center justify-center text-muted">{icon}</div>
        <span className="font-bold text-sm text-text">{label}</span>
      </div>
      <ChevronLeft size={16} className="text-muted rotate-180" />
    </button>
  );
}
