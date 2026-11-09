import Anthropic from "@anthropic-ai/sdk";
import type { Facts } from "./insights";

const MODEL = "claude-haiku-5-5";

const CACHE_TTL_MS = 2 * 60 * 60 * 1000;
const fullCache = new Map<string, string>();

function templateFallback(facts: Facts): string {
  if (facts.notable.length === 0) {
    return `Het netwerk levert nu ${facts.greenPct.toFixed(0)}% groene stroom.`;
  }
  return facts.notable.slice(0, 3).join(" ");
}

function compactPayload(facts: Facts) {
  return {
    tijd: new Date(facts.focusTime).toLocaleString("nl-NL", {
      weekday: "long",
      day: "numeric",
      month: "long",
      hour: "2-digit",
      minute: "2-digit",
      timeZone: "Europe/Amsterdam",
    }),
    is_dag: facts.isDaytime,
    is_toekomst: facts.isFuture,
    groen_pct: Math.round(facts.greenPct),
    top_bron: facts.topSource,
    bronnen: facts.sources.slice(0, 6).map((s) => ({
      naam: s.label,
      pct: Number(s.percentage.toFixed(1)),
      tov_normaal: s.ratio != null ? Number(s.ratio.toFixed(2)) : null,
    })),
    rule_based_feiten: facts.notable,
  };
}

function cacheKey(facts: Facts): string {
  return JSON.stringify({
    t: facts.focusTime,
    g: Math.round(facts.greenPct),
    s: facts.sources.map((s) => [s.typeId, Math.round(s.percentage), s.ratio ? Math.round(s.ratio * 10) : 0]),
  });
}

const SYSTEM_PROMPT =
  "Je schrijft 2 tot 3 korte, feitelijke Nederlandse zinnen voor een dashboard over de Nederlandse energiemix. " +
  "Geen marketingtoon, geen emojis, geen 'we' of 'wij', geen vragen, geen aanhalingstekens. " +
  "Begin nooit met de datum of het tijdstip: die wordt elders al getoond. " +
  "Begin direct met de meest opvallende observatie (bijv. 'Aardgas domineert...', 'Het waait flink...', 'Bewolkt en weinig wind...'). " +
  "Wees specifiek met getallen waar zinvol. " +
  "Als het toekomst is, gebruik toekomstvorm ('verwacht', 'zal'). " +
  "Maximaal 3 zinnen, samen onder de 50 woorden.";

function userPrompt(facts: Facts): string {
  return `Feiten:\n${JSON.stringify(compactPayload(facts), null, 2)}\n\nSchrijf de duiding.`;
}

let client: Anthropic | undefined;

function anthropic(): Anthropic | undefined {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) return undefined;
  client ??= new Anthropic({ apiKey, timeout: 20_000, maxRetries: 1 });
  return client;
}

export function cachedDescription(facts: Facts): string | undefined {
  return fullCache.get(cacheKey(facts));
}

function remember(key: string, text: string) {
  fullCache.set(key, text);
  setTimeout(() => {
    if (fullCache.get(key) === text) fullCache.delete(key);
  }, CACHE_TTL_MS).unref?.();
}

export async function* describeStream(facts: Facts): AsyncGenerator<string> {
  const key = cacheKey(facts);
  const cached = fullCache.get(key);
  if (cached) {
    yield cached;
    return;
  }

  const api = anthropic();
  if (!api) {
    yield templateFallback(facts);
    return;
  }

  let acc = "";
  const stream = api.messages.stream({
    model: MODEL,
    max_tokens: 4096,
    system: SYSTEM_PROMPT,
    output_config: { effort: "low" },
    messages: [{ role: "user", content: userPrompt(facts) }],
  });
  try {
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        acc += event.delta.text;
        yield event.delta.text;
      }
    }
  } catch (err) {
    if (err instanceof Anthropic.APIError) {
      console.error(`Anthropic stream failed (${err.status ?? "netwerk"}):`, err.message);
    } else {
      console.error("Anthropic stream failed:", err);
    }
  } finally {
    stream.abort();
  }

  const text = acc.trim();
  if (text.length > 0) {
    remember(key, text);
  } else {
    yield templateFallback(facts);
  }
}
