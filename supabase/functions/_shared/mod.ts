/**
 * Shared utilities barrel for FANZONE Edge Functions
 * Re-exports all modules for convenient importing
 *
 * Usage in functions:
 *   import { handleCors, jsonResponse, createAdminClient, requireAuth } from "../_shared/mod.ts";
 */

// CORS + HTTP helpers
export {
  corsHeaders,
  errorResponse,
  handleCors,
  jsonResponse,
} from "./cors.ts";

// HTTP authorization (FANZONE-original)
export {
  buildCorsHeaders,
  getErrorMessage,
  isAuthorizedByServiceRole,
  isAuthorizedEdgeRequest,
  readBearerToken,
} from "./http.ts";

// Structured logging
export {
  createLogger,
  generateRequestId,
  getOrCreateRequestId,
} from "./logger.ts";
export type { LogContext, Logger, LogLevel } from "./logger.ts";

// Types + enums
export { AuditAction, EntityType, ErrorCode } from "./types.ts";
export type { ApiResponse, AuthContext, RateLimitConfig } from "./types.ts";

// Auth + RBAC
export {
  checkRateLimit,
  createAdminClient,
  createUserClient,
  getActiveAdminRecord,
  getAuthenticatedUser,
  getAuthHeader,
  isAdmin,
  isVendorMember,
  optionalAuth,
  requireAdmin,
  requireAdminRole,
  requireAuth,
  requireVendorOrAdmin,
} from "./auth.ts";
export type { ActiveAdminRecord, AdminRole } from "./auth.ts";

// Audit logging
export { createAuditLogger, writeAuditLog } from "./audit.ts";
export type { AuditLogger, AuditMetadata } from "./audit.ts";

// Gemini AI utilities
export {
  buildAgentContext,
  callGemini,
  GEMINI_API_URL,
  GEMINI_MODELS,
  getAgentChatCompletion,
  parseJSON,
  searchPlaces,
  searchWithGoogle,
  streamAgentChat,
} from "./gemini.ts";
export type { AgentType, ConversationMessage, PlaceResult } from "./gemini.ts";
export { AGENT_SYSTEM_PROMPTS } from "./gemini.ts";
