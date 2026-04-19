// FANZONE Admin — AppShell (main layout wrapper)
import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function AppShell() {
  return (
    <div className="app-shell">
      <Sidebar />
      <div className="app-main">
        <Topbar />
        <main className="app-content">
          <Outlet />
        </main>
      </div>

      <style>{`
        .app-shell {
          display: flex;
          min-height: 100vh;
        }
        .app-main {
          flex: 1;
          margin-left: var(--fz-sidebar-w);
          min-width: 0;
          display: flex;
          flex-direction: column;
          transition: margin-left var(--fz-transition-slow);
        }
        .app-content {
          flex: 1;
          padding: var(--fz-sp-6);
          overflow-y: auto;
        }
      `}</style>
    </div>
  );
}
