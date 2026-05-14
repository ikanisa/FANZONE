import { Component, type ErrorInfo, type ReactNode } from "react";
import { AlertTriangle } from "lucide-react";

interface AppErrorBoundaryProps {
  children: ReactNode;
}

interface AppErrorBoundaryState {
  hasError: boolean;
}

export class AppErrorBoundary extends Component<
  AppErrorBoundaryProps,
  AppErrorBoundaryState
> {
  state: AppErrorBoundaryState = { hasError: false };

  static getDerivedStateFromError(): AppErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error(
      "[FANZONE Venue Portal] Unhandled render error",
      error,
      info.componentStack,
    );
  }

  private handleRetry = () => {
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <main className="min-h-screen bg-bg text-text flex items-center justify-center p-6">
          <section className="bg-surface border border-border rounded-[24px] p-10 text-center max-w-lg">
            <div className="w-16 h-16 bg-surface2 rounded-2xl flex items-center justify-center text-danger mx-auto mb-5">
              <AlertTriangle size={32} />
            </div>
            <h1 className="text-2xl font-black text-text">
              Venue portal crashed
            </h1>
            <p className="text-sm text-textSecondary font-medium mt-3">
              Reload the portal to recover the current venue session.
            </p>
            <button className="btn btn-primary mt-6" onClick={this.handleRetry}>
              Reload
            </button>
          </section>
        </main>
      );
    }

    return this.props.children;
  }
}
