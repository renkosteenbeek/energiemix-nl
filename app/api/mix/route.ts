import { computeFacts } from "@/lib/insights";
import { clampAt, getMixAt, latestAvailableHour } from "@/lib/ned";
import { errorResponse, failure, freshnessFor, getCached, jsonResponse, optionsResponse, setCache } from "@/lib/http";

export function OPTIONS() {
  return optionsResponse();
}

export async function GET(request: Request) {
  const atParam = new URL(request.url).searchParams.get("at");
  const at = atParam ? clampAt(new Date(atParam)) : latestAvailableHour();
  if (Number.isNaN(at.getTime())) return errorResponse(400, "ongeldige datum");

  const freshness = freshnessFor(at);
  const cacheKey = `mix:${at.toISOString().slice(0, 13)}`;
  const cached = getCached<unknown>(cacheKey);
  if (cached) return jsonResponse(cached, freshness.maxAgeSeconds);

  try {
    const mix = await getMixAt(at);
    const body = { at: at.toISOString(), mix, facts: await computeFacts(mix) };
    setCache(cacheKey, body, freshness.ttlMs);
    return jsonResponse(body, freshness.maxAgeSeconds);
  } catch (error) {
    return failure(error);
  }
}
