/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useEffect, type ReactNode } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useAppStore } from './store/useAppStore';
import { Splash } from './components/Splash';
import Layout from './components/Layout';
import HomeFeed from './components/HomeFeed';
import MatchDetail from './components/MatchDetail';
import Leaderboard from './components/Leaderboard';
import WalletHub from './components/WalletHub';
import Profile from './components/Profile';
import Fixtures from './components/Fixtures';
import Notifications from './components/Notifications';
import EmptyErrorStates from './components/EmptyErrorStates';
import LeagueHub from './components/LeagueHub';
import Settings from './components/Settings';
import TeamProfile from './components/TeamProfile';
import PrivacySettings from './components/PrivacySettings';
import Onboarding from './components/Onboarding';
import { AnimatePresence } from 'motion/react';
import { isPlatformFeatureVisible } from './platform/access';
import { PlatformBootstrapProvider, usePlatformBootstrap } from './platform/bootstrap';

function FeatureUnavailable({
  title,
  message,
}: {
  title: string;
  message: string;
}) {
  return (
    <div className="min-h-screen bg-bg px-4 py-10">
      <div className="mx-auto max-w-2xl rounded-[28px] border border-border bg-surface2 p-8">
        <div className="text-[10px] font-bold uppercase tracking-[0.3em] text-muted">
          Feature Control
        </div>
        <h1 className="mt-3 font-display text-3xl tracking-tight text-text">
          {title}
        </h1>
        <p className="mt-3 text-sm leading-6 text-muted">{message}</p>
      </div>
    </div>
  );
}

function FeatureRoute({
  featureKey,
  title,
  message,
  children,
}: {
  featureKey: string;
  title: string;
  message: string;
  children: ReactNode;
}) {
  usePlatformBootstrap();

  if (!isPlatformFeatureVisible(featureKey, { surface: 'route' })) {
    return <FeatureUnavailable title={title} message={message} />;
  }

  return children;
}

function RequireOnboarding({ children }: { children: ReactNode }) {
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
        <PlatformBootstrapProvider>
          <Router>
            <Routes>
              {/* Unauthenticated / Un-onboarded Route */}
              <Route
                path="/onboarding"
                element={
                  <FeatureRoute
                    featureKey="onboarding"
                    title="Onboarding is unavailable"
                    message="This onboarding flow is currently disabled by platform control."
                  >
                    <Onboarding />
                  </FeatureRoute>
                }
              />

              {/* Routes with Layout */}
              <Route path="/*" element={
                <RequireOnboarding>
                  <Layout>
                    <Routes>
                      <Route
                        path="/"
                        element={
                          <FeatureRoute
                            featureKey="home_feed"
                            title="Home feed is unavailable"
                            message="The homepage feed is currently hidden from the website."
                          >
                            <HomeFeed />
                          </FeatureRoute>
                        }
                      />
                      <Route
                        path="/match/:id"
                        element={
                          <FeatureRoute
                            featureKey="match_center"
                            title="Match center is unavailable"
                            message="This match center is currently disabled by platform control."
                          >
                            <MatchDetail />
                          </FeatureRoute>
                        }
                      />
                      <Route path="/league/:id" element={<LeagueHub />} />
                      <Route
                        path="/leaderboard"
                        element={
                          <FeatureRoute
                            featureKey="leaderboard"
                            title="Leaderboard is unavailable"
                            message="Leaderboard visibility is currently turned off for the website."
                          >
                            <Leaderboard />
                          </FeatureRoute>
                        }
                      />
                      <Route
                        path="/wallet"
                        element={
                          <FeatureRoute
                            featureKey="wallet"
                            title="Wallet is unavailable"
                            message="Wallet operations are currently disabled for the website."
                          >
                            <WalletHub />
                          </FeatureRoute>
                        }
                      />
                      <Route
                        path="/profile"
                        element={
                          <FeatureRoute
                            featureKey="profile"
                            title="Profile is unavailable"
                            message="Profile access is currently disabled for the website."
                          >
                            <Profile />
                          </FeatureRoute>
                        }
                      />
                      <Route
                        path="/settings"
                        element={
                          <FeatureRoute
                            featureKey="settings"
                            title="Settings are unavailable"
                            message="Preferences are currently disabled for the website."
                          >
                            <Settings />
                          </FeatureRoute>
                        }
                      />
                      <Route path="/team/:id" element={<TeamProfile />} />
                      <Route path="/privacy" element={<PrivacySettings />} />
                      <Route
                        path="/fixtures"
                        element={
                          <FeatureRoute
                            featureKey="fixtures"
                            title="Fixtures are unavailable"
                            message="Fixtures are currently hidden from the website."
                          >
                            <Fixtures />
                          </FeatureRoute>
                        }
                      />
                      <Route
                        path="/notifications"
                        element={
                          <FeatureRoute
                            featureKey="notifications"
                            title="Notifications are unavailable"
                            message="The notification center is currently disabled for the website."
                          >
                            <Notifications />
                          </FeatureRoute>
                        }
                      />
                      <Route path="/social" element={<Navigate to="/leaderboard" replace />} />
                      <Route path="/memberships" element={<Navigate to="/profile" replace />} />
                      <Route path="/fan-id" element={<Navigate to="/profile" replace />} />
                      <Route path="/rewards" element={<Navigate to="/wallet" replace />} />
                      <Route path="/error" element={<EmptyErrorStates />} />
                    </Routes>
                  </Layout>
                </RequireOnboarding>
              } />
            </Routes>
          </Router>
        </PlatformBootstrapProvider>
      )}
    </>
  );
}
