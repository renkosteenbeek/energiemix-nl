import Anthropic from "@anthropic-ai/sdk";
import type { DayFacts, Facts } from "./insights";
import { HOUR_MS } from "./ned";

const MODEL = "claude-haiku-5-5";
const DESCRIPTION_TTL_MS = 2 * HOUR_MS;
const descriptionCache = new Map<string, string>();

function templateFallback(facts: Facts): string {
  if (facts.notable.length === 0) {
    return `Het netwerk levert nu ${facts.greenPct.toFixed(0)}% groene stroom.`;
  }
  return facts.notable.slice(0, 3).join(" ");
}

function momentOf(focusTime: string): "verleden" | "nu" | "toekomst" {
  const start = new Date(focusTime).getTime();
  const now = Date.now();
  if (start > now) return "toekomst";
  return now - start < HOUR_MS ? "nu" : "verleden";
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
    moment: momentOf(facts.focusTime),
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
  "Kies de werkwoordstijd op basis van moment: verleden tijd bij 'verleden', tegenwoordige tijd bij 'nu', toekomstvorm ('verwacht', 'zal') bij 'toekomst'. Gebruik het woord 'nu' alleen als moment 'nu' is. " +
  "Maximaal 3 zinnen, samen onder de 50 woorden.";

const DAY_SYSTEM_PROMPT =
  "Je schrijft 2 tot 3 korte, feitelijke Nederlandse zinnen over de Nederlandse stroommix van één hele dag, voor een dashboard. " +
  "Geen marketingtoon, geen emojis, geen 'we' of 'wij', geen vragen, geen aanhalingstekens. " +
  "Begin nooit met de datum: die wordt elders al getoond. " +
  "Begin direct met de meest opvallende observatie. " +
  "Vergelijk waar zinvol met de dertig dagen ervoor (tov_gemiddelde). " +
  "Gebruik de verleden tijd, behalve als is_vandaag waar is: gebruik dan de tegenwoordige tijd en zeg dat de cijfers voorlopig zijn. " +
  "Maximaal 3 zinnen, samen onder de 50 woorden.";

function userPrompt(payload: unknown): string {
  return `Feiten:\n${JSON.stringify(payload, null, 2)}\n\nSchrijf de duiding.`;
}

function dayPayload(facts: DayFacts) {
  return {
    datum: new Date(`${facts.day}T12:00:00Z`).toLocaleDateString("nl-NL", {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "Europe/Amsterdam",
    }),
    is_vandaag: facts.isToday,
    groen_pct: Math.round(facts.greenPct),
    verbruik_gwh: Math.round(facts.totalKWh / 1_000_000),
    bronnen: facts.sources.slice(0, 6).map((s) => ({
      naam: s.label,
      pct: Number(s.percentage.toFixed(1)),
      tov_gemiddelde: s.ratio != null ? Number(s.ratio.toFixed(2)) : null,
    })),
    rule_based_feiten: facts.notable,
  };
}

function dayCacheKey(facts: DayFacts): string {
  return JSON.stringify({
    d: facts.day,
    g: Math.round(facts.greenPct),
    s: facts.sources.map((s) => [s.typeId, Math.round(s.percentage)]),
  });
}

function dayFallback(facts: DayFacts): string {
  if (facts.notable.length === 0) {
    return `Deze dag kwam ${facts.greenPct.toFixed(0)}% van de stroom uit duurzame bronnen.`;
  }
  return facts.notable.slice(0, 3).join(" ");
}

let client: Anthropic | undefined;

function anthropic(): Anthropic | undefined {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) return undefined;
  client ??= new Anthropic({ apiKey, timeout: 20_000, maxRetries: 1 });
  return client;
}

export type DescriptionChunk = { text: string; isFallback: boolean };

function remember(key: string, text: string) {
  descriptionCache.set(key, text);
  setTimeout(() => {
    if (descriptionCache.get(key) === text) descriptionCache.delete(key);
  }, DESCRIPTION_TTL_MS).unref?.();
}

export function describeStream(facts: Facts): AsyncGenerator<DescriptionChunk> {
  return streamDescription(cacheKey(facts), SYSTEM_PROMPT, userPrompt(compactPayload(facts)), templateFallback(facts));
}

export function describeDayStream(facts: DayFacts): AsyncGenerator<DescriptionChunk> {
  return streamDescription(dayCacheKey(facts), DAY_SYSTEM_PROMPT, userPrompt(dayPayload(facts)), dayFallback(facts));
}

async function* streamDescription(key: string, system: string, prompt: string, fallback: string): AsyncGenerator<DescriptionChunk> {
  const cached = descriptionCache.get(key);
  if (cached) {
    yield { text: cached, isFallback: false };
    return;
  }

  const api = anthropic();
  if (!api) {
    yield { text: fallback, isFallback: true };
    return;
  }

  let streamed = "";
  let completed = false;
  const stream = api.messages.stream({
    model: MODEL,
    max_tokens: 4096,
    system,
    output_config: { effort: "low" },
    messages: [{ role: "user", content: prompt }],
  });
  try {
    for await (const event of stream) {
      if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
        streamed += event.delta.text;
        yield { text: event.delta.text, isFallback: false };
      }
    }
    const final = await stream.finalMessage();
    completed = final.stop_reason === "end_turn";
  } catch (err) {
    if (err instanceof Anthropic.APIError) {
      console.error(`Anthropic stream failed (${err.status ?? "netwerk"}):`, err.message);
    } else {
      console.error("Anthropic stream failed:", err);
    }
  } finally {
    stream.abort();
  }

  const text = streamed.trim();
  if (completed && text.length > 0) {
    remember(key, text);
  } else if (text.length === 0) {
    yield { text: fallback, isFallback: true };
  } else {
    throw new Error("Duiding onvolledig");
  }
}
