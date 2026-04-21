/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useAppStore } from './store/useAppStore';
import { Splash } from './components/Splash';
import Layout from './components/Layout';
import HomeFeed from './components/HomeFeed';
import PredictionSlip from './components/PredictionSlip';
import MatchDetail from './components/MatchDetail';
import Leaderboard from './components/Leaderboard';
import WalletHub from './components/WalletHub';
import Profile from './components/Profile';
import Fixtures from './components/Fixtures';
import Notifications from './components/Notifications';
import EmptyErrorStates from './components/EmptyErrorStates';
import RewardsStore from './components/RewardsStore';
import JackpotPool from './components/JackpotPool';
import LeagueHub from './components/LeagueHub';
import SocialHub from './components/SocialHub';
import Settings from './components/Settings';
import MembershipHub from './components/MembershipHub';
import TeamProfile from './components/TeamProfile';
import FanIdScreen from './components/FanIdScreen';
import PrivacySettings from './components/PrivacySettings';
import Onboarding from './components/Onboarding';
import PoolsHub from './components/PoolsHub';
import PoolCreation from './components/PoolCreation';
import PoolDetail from './components/PoolDetail';
import { AnimatePresence } from 'motion/react';

function RequireOnboarding({ children }: { children: React.ReactNode }) {
  const { hasCompletedOnboarding } = useAppStore();
  if (!hasCompletedOnboarding) {
    return <Navigate to="/onboarding" replace />;
  }
  return children;
}

export default function App() {
  const { hasSeenSplash, theme } = useAppStore();

  useEffect(() => {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [theme]);

  return (
    <>
      <AnimatePresence>
        {!hasSeenSplash && <Splash />}
      </AnimatePresence>
      
      {hasSeenSplash && (
        <Router>
          <Routes>
            {/* Unauthenticated / Un-onboarded Route */}
            <Route path="/onboarding" element={<Onboarding />} />

            {/* Routes with Layout */}
            <Route path="/*" element={
              <RequireOnboarding>
                <Layout>
                  <Routes>
                    <Route path="/" element={<HomeFeed />} />
                    <Route path="/match/:id" element={<MatchDetail />} />
                    <Route path="/league/:id" element={<LeagueHub />} />
                    <Route path="/leaderboard" element={<Leaderboard />} />
                    <Route path="/wallet" element={<WalletHub />} />
                    <Route path="/profile" element={<Profile />} />
                    <Route path="/pools" element={<PoolsHub />} />
                    <Route path="/pools/create" element={<PoolCreation />} />
                    <Route path="/pool/:id" element={<PoolDetail />} />
                    <Route path="/social" element={<SocialHub />} />
                    <Route path="/settings" element={<Settings />} />
                    <Route path="/memberships" element={<MembershipHub />} />
                    <Route path="/team/:id" element={<TeamProfile />} />
                    <Route path="/fan-id" element={<FanIdScreen />} />
                    <Route path="/privacy" element={<PrivacySettings />} />
                    <Route path="/fixtures" element={<Fixtures />} />
                    <Route path="/notifications" element={<Notifications />} />
                    <Route path="/rewards" element={<RewardsStore />} />
                    <Route path="/jackpot" element={<JackpotPool />} />
                    <Route path="/error" element={<EmptyErrorStates />} />
                  </Routes>
                  <PredictionSlip />
                </Layout>
              </RequireOnboarding>
            } />
          </Routes>
        </Router>
      )}
    </>
  );
}

