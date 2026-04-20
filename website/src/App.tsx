/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { Suspense, lazy, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useAppStore } from './store/useAppStore';
import { Splash } from './components/Splash';
import { AnimatePresence } from 'motion/react';

const Layout = lazy(() => import('./components/Layout'));
const HomeFeed = lazy(() => import('./components/HomeFeed'));
const PredictionSlip = lazy(() => import('./components/PredictionSlip'));
const MatchDetail = lazy(() => import('./components/MatchDetail'));
const Leaderboard = lazy(() => import('./components/Leaderboard'));
const WalletHub = lazy(() => import('./components/WalletHub'));
const Profile = lazy(() => import('./components/Profile'));
const Fixtures = lazy(() => import('./components/Fixtures'));
const Notifications = lazy(() => import('./components/Notifications'));
const EmptyErrorStates = lazy(() => import('./components/EmptyErrorStates'));
const RewardsStore = lazy(() => import('./components/RewardsStore'));
const JackpotPool = lazy(() => import('./components/JackpotPool'));
const LeagueHub = lazy(() => import('./components/LeagueHub'));
const SocialHub = lazy(() => import('./components/SocialHub'));
const Settings = lazy(() => import('./components/Settings'));
const MembershipHub = lazy(() => import('./components/MembershipHub'));
const TeamProfile = lazy(() => import('./components/TeamProfile'));
const FanIdScreen = lazy(() => import('./components/FanIdScreen'));
const PrivacySettings = lazy(() => import('./components/PrivacySettings'));
const Onboarding = lazy(() => import('./components/Onboarding'));
const PoolsHub = lazy(() => import('./components/PoolsHub'));
const PoolCreation = lazy(() => import('./components/PoolCreation'));
const PoolDetail = lazy(() => import('./components/PoolDetail'));

function RouteFallback() {
  return <div className="min-h-screen bg-bg" />;
}

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
          <Suspense fallback={<RouteFallback />}>
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
          </Suspense>
        </Router>
      )}
    </>
  );
}
