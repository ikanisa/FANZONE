/**
 * Shared utilities barrel for FANZONE Edge Functions
 * Re-exports all modules for convenient importing
 *
 * Usage in functions:
 *   import { handleCors, jsonResponse, createAdminClient, requireAuth } from "../_shared/mod.ts";
 */

// CORS + HTTP helpers
export { corsHeaders, handleCors, jsonResponse, errorResponse } from "./cors.ts";

// HTTP authorization (FANZONE-original)
export {
    buildCorsHeaders,
    readBearerToken,
    isAuthorizedEdgeRequest,
    isAuthorizedByServiceRole,
    getErrorMessage,
} from "./http.ts";

// Structured logging
export { createLogger, getOrCreateRequestId, generateRequestId } from "./logger.ts";
export type { Logger, LogLevel, LogContext } from "./logger.ts";

// Types + enums
export { AuditAction, EntityType, ErrorCode } from "./types.ts";
export type { AuthContext, ApiResponse, RateLimitConfig } from "./types.ts";

// Auth + RBAC
export {
    createAdminClient,
    createUserClient,
    getAuthHeader,
    getAuthenticatedUser,
    requireAuth,
    optionalAuth,
    isAdmin,
    isVendorMember,
    requireAdmin,
    requireVendorOrAdmin,
    checkRateLimit,
} from "./auth.ts";

// Audit logging
export { writeAuditLog, createAuditLogger } from "./audit.ts";
export type { AuditMetadata, AuditLogger } from "./audit.ts";

// Gemini AI utilities
export {
    GEMINI_API_URL,
    GEMINI_MODELS,
    callGemini,
    searchWithGoogle,
    searchPlaces,
    parseJSON,
    buildAgentContext,
    streamAgentChat,
    getAgentChatCompletion,
} from "./gemini.ts";
export type { PlaceResult, AgentType, ConversationMessage } from "./gemini.ts";
export { AGENT_SYSTEM_PROMPTS } from "./gemini.ts";
