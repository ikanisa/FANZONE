/**
 * Gemini AI utilities for FANZONE Edge Functions.
 *
 * Provides:
 *  - callGemini() — primary/fallback model calls with retry + exponential backoff
 *  - parseJSON() — robust JSON extraction from AI text responses
 *  - searchWithGoogle() — Google Search grounding via Gemini
 *  - searchPlaces() — Place discovery via Gemini grounding
 *  - Agent chat (streaming + non-streaming) for guest/bar_manager/admin bots
 */

// Gemini API Configuration
export const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta";
export const GEMINI_MODELS = {
    text: "gemini-2.5-flash",
    textFallback: "gemini-2.5-pro",
    vision: "gemini-2.5-flash",
    visionFallback: "gemini-2.5-pro",
    imagePro: "nano-banana-pro-preview",
    imageFast: "imagen-4.0-fast-generate-001",
    categorizeVenue: "gemini-2.0-flash-001",
    categorizeMenu: "gemini-2.5-flash",
};

/**
 * Call Gemini API with primary/fallback model support and retry logic
 */
export async function callGemini(
    model: string,
    prompt: string,
    options: {
        tools?: any[];
        toolConfig?: any;
        temperature?: number;
        maxTokens?: number;
        imageData?: string;
        mimeType?: string;
        responseMimeType?: string;
        apiKey?: string;
        enableGoogleSearch?: boolean;
    } = {}
) {
    const apiKey = options.apiKey || Deno.env.get("GEMINI_API_KEY") || Deno.env.get("API_KEY");
    if (!apiKey) {
        throw new Error("GEMINI_API_KEY not configured");
    }

    // Determine primary and fallback models
    let primaryModel = model || GEMINI_MODELS.text;
    let fallbackModel: string | null = null;

    if (primaryModel === GEMINI_MODELS.text) {
        fallbackModel = GEMINI_MODELS.textFallback;
    } else if (primaryModel === GEMINI_MODELS.vision) {
        fallbackModel = GEMINI_MODELS.visionFallback;
    }

    const parts: any[] = [];
    if (prompt) parts.push({ text: prompt });
    if (options.imageData && options.mimeType) {
        parts.push({
            inlineData: {
                data: options.imageData,
                mimeType: options.mimeType,
            },
        });
    }

    const requestBody: any = {
        contents: [{ role: "user", parts }],
        generationConfig: {
            temperature: options.temperature ?? 0.7,
            maxOutputTokens: options.maxTokens ?? 2048,
            responseMimeType: options.responseMimeType,
        },
    };

    // Add tools — either custom tools or Google Search grounding
    if (options.enableGoogleSearch) {
        requestBody.tools = [{ google_search: {} }];
        console.log("[Gemini] Google Search grounding enabled");
    } else if (options.tools?.length) {
        requestBody.tools = options.tools;
    }
    if (options.toolConfig) requestBody.toolConfig = options.toolConfig;

    // Retry logic
    const MAX_RETRIES = 3;
    const RETRY_DELAY = 1000;

    async function fetchWithRetry(modelName: string): Promise<any> {
        let attempt = 0;
        while (attempt < MAX_RETRIES) {
            try {
                const url = `${GEMINI_API_URL}/models/${modelName}:generateContent?key=${apiKey}`;
                const response = await fetch(url, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(requestBody),
                });

                if (!response.ok && (response.status === 429 || response.status >= 500)) {
                    if (attempt < MAX_RETRIES - 1) {
                        const delay = RETRY_DELAY * Math.pow(2, attempt);
                        console.warn(`Attempt ${attempt + 1} failed for ${modelName} (${response.status}), retrying in ${delay}ms...`);
                        await new Promise((resolve) => setTimeout(resolve, delay));
                        attempt++;
                        continue;
                    }
                }

                if (!response.ok) {
                    const text = await response.text();
                    throw new Error(`${response.status} - ${text.substring(0, 200)}`);
                }

                return await response.json();
            } catch (err) {
                if (attempt < MAX_RETRIES - 1) {
                    const delay = RETRY_DELAY * Math.pow(2, attempt);
                    console.warn(`Network error on ${modelName}, retrying in ${delay}ms...`, err);
                    await new Promise((resolve) => setTimeout(resolve, delay));
                    attempt++;
                    continue;
                }
                throw err;
            }
        }
    }

    let data;
    try {
        data = await fetchWithRetry(primaryModel);
        console.log("Gemini Raw Response:", JSON.stringify(data).substring(0, 2000));
    } catch (error) {
        if (fallbackModel) {
            console.warn(`Primary model ${primaryModel} failed after retries, trying fallback ${fallbackModel}`, error);
            try {
                data = await fetchWithRetry(fallbackModel);
            } catch (fallbackError) {
                throw new Error(`Gemini API failed on primary and fallback: ${fallbackError}`);
            }
        } else {
            throw new Error(`Gemini API failed: ${error}`);
        }
    }

    // Extract text content
    if (data.candidates?.[0]?.content?.parts) {
        const textPart = data.candidates[0].content.parts.find((p: any) => p.text);
        if (textPart?.text) {
            return { text: textPart.text, raw: data };
        }
    }

    return { raw: data };
}

/**
 * Search the web using Gemini's Google Search grounding
 */
export async function searchWithGoogle(
    query: string,
    options: { geo?: "RW" | "MT"; maxResults?: number } = {}
): Promise<{ results: Array<{ title: string; url: string; snippet: string }>; raw?: any }> {
    const geoContext =
        options.geo === "RW" ? "Rwanda, East Africa" : options.geo === "MT" ? "Malta, Europe" : "";

    const prompt = `${query}${geoContext ? ` (focus on ${geoContext})` : ""}\n\nProvide a factual answer with sources.`;

    const result = await callGemini("gemini-2.0-flash", prompt, {
        enableGoogleSearch: true,
        temperature: 0.3,
        maxTokens: 2048,
    });

    const groundingMeta = result.raw?.candidates?.[0]?.groundingMetadata;
    const results: Array<{ title: string; url: string; snippet: string }> = [];

    if (groundingMeta?.groundingChunks) {
        for (const chunk of groundingMeta.groundingChunks.slice(0, options.maxResults || 5)) {
            if (chunk.web) {
                results.push({
                    title: chunk.web.title || "Untitled",
                    url: chunk.web.uri || "",
                    snippet: chunk.web.snippet || "",
                });
            }
        }
    }

    if (results.length === 0 && result.text) {
        results.push({ title: "Search Result", url: "", snippet: result.text.substring(0, 500) });
    }

    return { results, raw: result.raw };
}

/**
 * Place discovery via Gemini grounding
 */
export interface PlaceResult {
    name: string;
    address?: string;
    rating?: number;
    priceLevel?: string;
    cuisine?: string;
    phone?: string;
    website?: string;
    openNow?: boolean;
    description?: string;
    sourceUrl?: string;
}

export async function searchPlaces(
    query: string,
    options: { geo: "RW" | "MT"; type?: string; limit?: number }
): Promise<{ places: PlaceResult[]; raw?: any }> {
    const geoContext = options.geo === "RW" ? "Kigali, Rwanda" : "Malta";
    const placeType = options.type || "restaurant";
    const limit = options.limit || 5;

    const prompt = `Find ${limit} well-reviewed ${placeType}s in ${geoContext} that match: "${query}"\n\nList the name, address, and brief description of each place. Only include real, currently operating establishments.`;

    const result = await callGemini(GEMINI_MODELS.text, prompt, {
        enableGoogleSearch: true,
        temperature: 0.3,
        maxTokens: 3000,
    });

    const places: PlaceResult[] = [];

    if (result.text) {
        try {
            const parsed = JSON.parse(result.text);
            if (Array.isArray(parsed)) {
                for (const p of parsed.slice(0, limit)) {
                    places.push({
                        name: p.name || "Unknown",
                        address: p.address,
                        rating: p.rating,
                        description: p.description,
                    });
                }
            }
        } catch {
            // Extract from natural text
            const lines = result.text.split("\n");
            for (const line of lines) {
                const match = line.trim().match(/^[\*\-\d\.]+\s*(.+)/);
                if (match?.[1]) {
                    const name = match[1].trim();
                    if (name.length > 2 && name.length < 100 && !name.startsWith("http")) {
                        places.push({ name });
                        if (places.length >= limit) break;
                    }
                }
            }
        }
    }

    // Enrich with grounding sources
    const groundingMeta = result.raw?.candidates?.[0]?.groundingMetadata;
    if (groundingMeta?.groundingChunks && places.length > 0) {
        const chunks = groundingMeta.groundingChunks;
        for (let i = 0; i < Math.min(places.length, chunks.length); i++) {
            if (chunks[i]?.web?.uri) places[i].sourceUrl = chunks[i].web.uri;
        }
    }

    return { places, raw: result.raw };
}

/**
 * Parse JSON from AI text response with error handling
 */
export function parseJSON(text: string | undefined, fallback: any = []): any {
    if (!text) return fallback;
    const jsonMatch = text.match(/\[[\s\S]*\]|\{[\s\S]*\}/);
    if (!jsonMatch) return fallback;

    let jsonText = jsonMatch[0].replace(/,(\s*[}\]])/g, "$1");
    try {
        return JSON.parse(jsonText);
    } catch (e) {
        console.error("JSON parse error:", e);
        console.warn("Failed JSON text:", text?.substring(0, 1000));
        return fallback;
    }
}

// =============================================================================
// AGENT CHAT FUNCTIONALITY
// =============================================================================

export type AgentType = "guest" | "bar_manager" | "admin";

export const AGENT_SYSTEM_PROMPTS: Record<AgentType, string> = {
    guest: `You are a friendly, knowledgeable AI waiter at a sports bar. Your role is to:

1. **Welcome Guests** - Greet warmly, explain you can help with menu and orders
2. **Menu Assistance** - Answer questions about items, suggest recommendations
3. **Order Taking** - Take orders conversationally, confirm items, suggest pairings
4. **Order Tracking** - Update on order status when asked
5. **FET Rewards** - Explain how ordering can earn FET for wallet rewards and match pools

**Important Rules:**
- Always confirm orders before submitting
- Be honest about wait times and availability
- Use emojis sparingly (🍽️ 🍷 ✨ ⚽)
- Keep messages concise but warm
- If unsure, suggest calling a human waiter
- Never make up menu items or prices`,

    bar_manager: `You are a professional business assistant helping bar/restaurant managers with daily operations. Your role is to:

1. **Order Management** - Summarize active orders, highlight urgent items
2. **Analytics** - Provide insights on sales, popular items, peak hours
3. **Operational Support** - Answer questions about workflow, status updates
4. **FET & Pools** - Monitor match pool activity at the venue

**Important Rules:**
- Be direct and actionable
- Use numbers and data when available
- Format lists and summaries clearly
- Prioritize urgent information first`,

    admin: `You are a platform management assistant helping FANZONE administrators. Your role is to:

1. **Application Review** - Summarize venue applications, highlight key details
2. **Moderation Support** - Help review flagged content or issues
3. **Platform Insights** - Provide analytics on platform usage
4. **FET Economy** - Monitor FET circulation, pool health, settlement status

**Important Rules:**
- Be impartial and thorough
- Document reasoning for decisions
- Prioritize based on urgency
- Highlight any compliance or risk concerns`,
};

export interface ConversationMessage {
    role: "user" | "assistant" | "system";
    content: string;
}

/**
 * Build context string for AI agent conversations
 */
export function buildAgentContext(context: {
    venue?: { name: string; id: string } | null;
    table_no?: string | null;
    menu_items?: Array<{ name: string; price: number; description?: string; currency?: string }>;
    active_orders?: Array<{ id: string; status: string; items: string[] }>;
    pending_claims?: number;
}): string {
    const parts: string[] = [];
    if (context.venue) parts.push(`**Current Venue:** ${context.venue.name}`);
    if (context.table_no) parts.push(`**Table Number:** ${context.table_no}`);
    if (context.menu_items?.length) {
        const menuStr = context.menu_items
            .slice(0, 15)
            .map((m) => `- ${m.name}: ${m.price} ${m.currency || ""} ${m.description ? `(${m.description})` : ""}`)
            .join("\n");
        parts.push(`**Available Menu Items:**\n${menuStr}`);
    }
    if (context.active_orders?.length) {
        const ordersStr = context.active_orders
            .map((o) => `- Order ${o.id.slice(0, 8)}: ${o.status} - ${o.items.join(", ")}`)
            .join("\n");
        parts.push(`**Active Orders:**\n${ordersStr}`);
    }
    if (context.pending_claims !== undefined && context.pending_claims > 0) {
        parts.push(`**Pending Venue Claims:** ${context.pending_claims}`);
    }
    return parts.length > 0 ? `\n\n**Context:**\n${parts.join("\n\n")}` : "";
}

/**
 * Streaming chat completion for agent conversations
 */
export async function streamAgentChat(
    agentType: AgentType,
    messages: ConversationMessage[],
    contextString: string = ""
): Promise<ReadableStream<Uint8Array>> {
    const apiKey = Deno.env.get("GEMINI_API_KEY") || Deno.env.get("API_KEY");
    if (!apiKey) throw new Error("GEMINI_API_KEY not configured");

    const systemPrompt = AGENT_SYSTEM_PROMPTS[agentType] + contextString;
    const geminiMessages = messages
        .filter((m) => m.role !== "system")
        .map((m) => ({
            role: m.role === "user" ? "user" : "model",
            parts: [{ text: m.content }],
        }));

    const url = `${GEMINI_API_URL}/models/gemini-2.0-flash:streamGenerateContent?key=${apiKey}`;
    const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
            systemInstruction: { parts: [{ text: systemPrompt }] },
            contents: geminiMessages,
            generationConfig: { temperature: 0.7, maxOutputTokens: 1024, topP: 0.9 },
        }),
    });

    if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }
    return response.body!;
}

/**
 * Non-streaming agent chat completion
 */
export async function getAgentChatCompletion(
    agentType: AgentType,
    messages: ConversationMessage[],
    contextString: string = ""
): Promise<string> {
    const systemPrompt = AGENT_SYSTEM_PROMPTS[agentType] + contextString;
    const conversationText = messages.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join("\n\n");

    const result = await callGemini("gemini-2.0-flash", `${systemPrompt}\n\n---\n\nConversation:\n${conversationText}`, {
        temperature: 0.7,
        maxTokens: 1024,
    });

    return result.text || "";
}
