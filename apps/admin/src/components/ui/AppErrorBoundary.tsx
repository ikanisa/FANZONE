import { Component, type ErrorInfo, type ReactNode } from "react";
import { ErrorState } from "./StateViews";

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
      "[FANZONE Admin] Unhandled render error",
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
        <ErrorState
          title="Admin panel crashed"
          description="Reload the panel to recover the current session."
          onRetry={this.handleRetry}
        />
      );
    }

    return this.props.children;
  }
}
