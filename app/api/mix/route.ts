import { NextResponse } from "next/server";
import { computeFacts } from "@/lib/insights";
import { clampAt, getMixAt, latestAvailableHour } from "@/lib/ned";
import { cacheControl, getCached, setCache, withCors } from "@/lib/responseCache";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: withCors({}) });
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const atParam = url.searchParams.get("at");
  const at = atParam ? clampAt(new Date(atParam)) : latestAvailableHour();

  if (Number.isNaN(at.getTime())) {
    return NextResponse.json({ error: "ongeldige datum" }, { status: 400 });
  }

  const hourKey = at.toISOString().slice(0, 13);
  const cacheKey = `mix:${hourKey}`;

  const cached = getCached<{ at: string; mix: unknown; facts: unknown }>(cacheKey);
  if (cached) {
    return NextResponse.json(cached, {
      headers: withCors({ "Cache-Control": cacheControl(at) }),
    });
  }

  try {
    const mix = await getMixAt(at);
    const facts = await computeFacts(at, mix);
    const body = { at: at.toISOString(), mix, facts };

    const now = Date.now();
    const hourAgo = now - 60 * 60 * 1000;
    const ttl = at.getTime() < hourAgo ? 3600_000 : 300_000;
    setCache(cacheKey, body, ttl);

    return NextResponse.json(body, {
      headers: withCors({ "Cache-Control": cacheControl(at) }),
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "fout" },
      { status: 500 },
    );
  }
}
