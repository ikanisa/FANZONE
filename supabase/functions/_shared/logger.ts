/**
 * Structured logger for Edge Functions.
 */

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogContext {
  requestId: string;
  userId?: string;
  vendorId?: string;
  action?: string;
  [key: string]: unknown;
}

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  requestId: string;
  message: string;
  context?: Record<string, unknown>;
}

/**
 * Generate a unique request ID for tracing
 */
export function generateRequestId(): string {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substring(2, 8);
  return `req_${timestamp}_${random}`;
}

/**
 * Get request ID from header or generate new one
 */
export function getOrCreateRequestId(req: Request): string {
  return req.headers.get("x-request-id") || generateRequestId();
}

/**
 * Create a logger instance bound to a specific request context
 */
export function createLogger(baseContext: LogContext) {
  const log = (
    level: LogLevel,
    message: string,
    extra?: Record<string, unknown>,
  ) => {
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      requestId: baseContext.requestId,
      message,
      context: {
        ...baseContext,
        ...extra,
      },
    };

    const logLine = JSON.stringify(entry);

    switch (level) {
      case "error":
        console.error(logLine);
        break;
      case "warn":
        console.warn(logLine);
        break;
      case "debug":
        console.debug(logLine);
        break;
      default:
        console.log(logLine);
    }
  };

  return {
    debug: (message: string, extra?: Record<string, unknown>) =>
      log("debug", message, extra),
    info: (message: string, extra?: Record<string, unknown>) =>
      log("info", message, extra),
    warn: (message: string, extra?: Record<string, unknown>) =>
      log("warn", message, extra),
    error: (message: string, extra?: Record<string, unknown>) =>
      log("error", message, extra),

    requestStart: (method: string, path: string) => {
      log("info", `Request started: ${method} ${path}`, { method, path });
    },

    requestEnd: (status: number, durationMs: number) => {
      log("info", `Request completed: ${status}`, { status, durationMs });
    },
  };
}

export type Logger = ReturnType<typeof createLogger>;
