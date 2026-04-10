import { NextResponse } from "next/server";
import { getGreenTimeline } from "@/lib/ned";
import { cacheControl, getCached, setCache, withCors } from "@/lib/responseCache";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: withCors({}) });
}

export async function GET() {
  const now = new Date();
  const cacheKey = `timeline:${now.toISOString().slice(0, 13)}`;

  const cached = getCached<unknown>(cacheKey);
  if (cached) {
    return NextResponse.json(cached, {
      headers: withCors({ "Cache-Control": "public, max-age=300" }),
    });
  }

  try {
    const timeline = await getGreenTimeline(now, 720, 24);
    setCache(cacheKey, timeline, 300_000);
    return NextResponse.json(timeline, {
      headers: withCors({ "Cache-Control": "public, max-age=300" }),
    });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "fout" },
      { status: 500 },
    );
  }
}
