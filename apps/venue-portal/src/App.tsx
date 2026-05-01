import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AppShell } from './components/layout/AppShell';
import { VenueProvider } from './hooks/useVenueContext';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { MenuArchitectPage } from './features/menu/MenuArchitectPage';
import { LiveOrderQueuePage } from './features/orders/LiveOrderQueuePage';
import { QRFactoryPage } from './features/settings/QRFactoryPage';

// Placeholder for future features
const Placeholder = ({ title }: { title: string }) => (
  <div className="flex flex-col items-center justify-center min-h-[60vh] text-center">
    <h2 className="text-3xl font-black mb-2">{title}</h2>
    <p className="text-textSecondary">Feature implementation in progress...</p>
  </div>
);

function App() {
  return (
    <VenueProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<AppShell />}>
            <Route index element={<DashboardPage />} />
            <Route path="menu" element={<MenuArchitectPage />} />
            <Route path="orders" element={<LiveOrderQueuePage />} />
            <Route path="stakes" element={<Placeholder title="Match Stakes & Pools" />} />
            <Route path="analytics" element={<Placeholder title="Operational Analytics" />} />
            <Route path="settings" element={<QRFactoryPage />} />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </VenueProvider>
  );
}

export default App;
