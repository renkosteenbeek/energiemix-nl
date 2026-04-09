import OpenAI from "openai";
import type { Facts } from "./insights";

const fullCache = new Map<string, string>();
const inflightCache = new Map<string, Promise<string>>();

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

function buildMessages(facts: Facts) {
  return [
    {
      role: "system" as const,
      content:
        "Je schrijft 2 tot 3 korte, feitelijke Nederlandse zinnen voor een dashboard over de Nederlandse energiemix. " +
        "Geen marketingtoon, geen emojis, geen 'we' of 'wij', geen vragen, geen aanhalingstekens. " +
        "Begin nooit met de datum of het tijdstip — die wordt elders al getoond. " +
        "Begin direct met de meest opvallende observatie (bijv. 'Aardgas domineert...', 'Het waait flink...', 'Bewolkt en weinig wind...'). " +
        "Wees specifiek met getallen waar zinvol. " +
        "Als het toekomst is, gebruik toekomstvorm ('verwacht', 'zal'). " +
        "Maximaal 3 zinnen, samen onder de 50 woorden.",
    },
    {
      role: "user" as const,
      content: `Feiten:\n${JSON.stringify(compactPayload(facts), null, 2)}\n\nSchrijf de duiding.`,
    },
  ];
}

export async function describe(facts: Facts): Promise<string> {
  const key = cacheKey(facts);
  const cached = fullCache.get(key);
  if (cached) return cached;
  const inflight = inflightCache.get(key);
  if (inflight) return inflight;

  const promise = (async () => {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) return templateFallback(facts);

    try {
      const client = new OpenAI({ apiKey });
      const model = process.env.OPENAI_MODEL ?? "gpt-5-nano";
      const completion = await client.chat.completions.create({
        model,
        messages: buildMessages(facts),
      });
      const text = completion.choices[0]?.message?.content?.trim();
      const result = text && text.length > 0 ? text : templateFallback(facts);
      fullCache.set(key, result);
      return result;
    } catch (err) {
      console.error("LLM describe failed:", err);
      return templateFallback(facts);
    } finally {
      inflightCache.delete(key);
    }
  })();

  inflightCache.set(key, promise);
  setTimeout(() => fullCache.delete(key), 2 * 60 * 60 * 1000).unref?.();
  return promise;
}

export async function* describeStream(facts: Facts): AsyncGenerator<string> {
  const key = cacheKey(facts);
  const cached = fullCache.get(key);
  if (cached) {
    yield cached;
    return;
  }

  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    yield templateFallback(facts);
    return;
  }

  try {
    const client = new OpenAI({ apiKey });
    const model = process.env.OPENAI_MODEL ?? "gpt-5-nano";
    const stream = await client.chat.completions.create({
      model,
      messages: buildMessages(facts),
      stream: true,
    });

    let acc = "";
    for await (const chunk of stream) {
      const delta = chunk.choices[0]?.delta?.content ?? "";
      if (delta) {
        acc += delta;
        yield delta;
      }
    }
    if (acc.trim().length > 0) {
      fullCache.set(key, acc.trim());
      setTimeout(() => fullCache.delete(key), 2 * 60 * 60 * 1000).unref?.();
    } else {
      yield templateFallback(facts);
    }
  } catch (err) {
    console.error("LLM stream failed:", err);
    yield templateFallback(facts);
  }
}
