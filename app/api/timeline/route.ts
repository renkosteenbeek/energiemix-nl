import { NextResponse } from "next/server";
import { DAILY_MIN_DAY, getGreenTimeline, NED_MAX_FORECAST_AHEAD_MS } from "@/lib/ned";
import { getCached, setCache, withCors } from "@/lib/responseCache";

const HOUR_MS = 60 * 60 * 1000;
const MAX_RANGE_HOURS = 31 * 24;

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: withCors({}) });
}

function floorToHour(date: Date): Date {
  return new Date(Math.floor(date.getTime() / HOUR_MS) * HOUR_MS);
}

async function rangeResponse(fromParam: string | null, toParam: string | null) {
  const earliest = new Date(`${DAILY_MIN_DAY}T00:00:00Z`).getTime() - 24 * HOUR_MS;
  const requested = floorToHour(new Date(fromParam ?? ""));
  const from = new Date(Math.max(requested.getTime(), earliest));
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
    return NextResponse.json({ error: "ongeldige periode" }, { status: 400, headers: withCors({}) });
  }

  const isSettled = to.getTime() < now - HOUR_MS;
  const cacheKey = `timeline:${from.toISOString()}:${to.toISOString()}`;
  const cacheHeader = isSettled ? "public, max-age=3600" : "public, max-age=300";
  const cached = getCached<unknown>(cacheKey);
  if (cached) {
    return NextResponse.json(cached, { headers: withCors({ "Cache-Control": cacheHeader }) });
  }

  const timeline = await getGreenTimeline(from, 0, hours);
  setCache(cacheKey, timeline, isSettled ? 3_600_000 : 300_000);
  return NextResponse.json(timeline, { headers: withCors({ "Cache-Control": cacheHeader }) });
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
    if (cached) {
      return NextResponse.json(cached, {
        headers: withCors({ "Cache-Control": "public, max-age=300" }),
      });
    }

    const timeline = await getGreenTimeline(now, 720, 24);
    setCache(cacheKey, timeline, 300_000);
    return NextResponse.json(timeline, {
      headers: withCors({ "Cache-Control": "public, max-age=300" }),
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "fout" },
      { status: 500, headers: withCors({}) },
    );
  }
}
