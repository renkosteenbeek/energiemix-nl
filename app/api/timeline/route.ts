import { DATA_START, getGreenTimeline, HOUR_MS, NED_MAX_FORECAST_AHEAD_MS } from "@/lib/ned";
import { errorResponse, failure, getCached, jsonResponse, optionsResponse, setCache } from "@/lib/http";

const MAX_RANGE_HOURS = 31 * 24;

export function OPTIONS() {
  return optionsResponse();
}

function floorToHour(date: Date): Date {
  return new Date(Math.floor(date.getTime() / HOUR_MS) * HOUR_MS);
}

async function rangeResponse(fromParam: string | null, toParam: string | null) {
  const requested = floorToHour(new Date(fromParam ?? ""));
  const from = new Date(Math.max(requested.getTime(), DATA_START.getTime() - 24 * HOUR_MS));
  const to = floorToHour(new Date(toParam ?? ""));
  const hours = Math.round((to.getTime() - from.getTime()) / HOUR_MS);
  const now = Date.now();

  if (
    Number.isNaN(requested.getTime()) ||
    Number.isNaN(to.getTime()) ||
    hours <= 0 ||
    hours > MAX_RANGE_HOURS ||
    to.getTime() > now + NED_MAX_FORECAST_AHEAD_MS
  ) {
    return errorResponse(400, "ongeldige periode");
  }

  const isSettled = to.getTime() < now - HOUR_MS;
  const maxAge = isSettled ? 3600 : 300;
  const cacheKey = `timeline:${from.toISOString()}:${to.toISOString()}`;
  const cached = getCached<unknown>(cacheKey);
  if (cached) return jsonResponse(cached, maxAge);

  const timeline = await getGreenTimeline(from, 0, hours);
  setCache(cacheKey, timeline, maxAge * 1000);
  return jsonResponse(timeline, maxAge);
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const fromParam = url.searchParams.get("from");
  const toParam = url.searchParams.get("to");

  try {
    if (fromParam || toParam) return await rangeResponse(fromParam, toParam);

    const now = new Date();
    const cacheKey = `timeline:${now.toISOString().slice(0, 13)}`;
    const cached = getCached<unknown>(cacheKey);
    if (cached) return jsonResponse(cached, 300);

    const timeline = await getGreenTimeline(now, 720, 24);
    setCache(cacheKey, timeline, 300_000);
    return jsonResponse(timeline, 300);
  } catch (error) {
    return failure(error);
  }
}
