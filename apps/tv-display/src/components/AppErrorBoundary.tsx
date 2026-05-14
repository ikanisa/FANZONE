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
      "[FANZONE TV Display] Unhandled render error",
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
        <main className="tv-shell flex min-h-screen items-center justify-center text-center">
          <div className="screen-backdrop">
            <div />
          </div>
          <section className="primary-card pairing-card max-w-2xl">
            <AlertTriangle size={56} color="var(--fz-error)" />
            <p className="eyebrow">Display interrupted</p>
            <h2>Reload the venue screen</h2>
            <p className="text-muted">
              The TV display hit a render error and needs a refresh to continue.
            </p>
            <button onClick={this.handleRetry}>Reload</button>
          </section>
        </main>
      );
    }

    return this.props.children;
  }
}
