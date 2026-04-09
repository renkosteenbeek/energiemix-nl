import { NextResponse } from "next/server";
import { computeFacts } from "@/lib/insights";
import { clampAt, getMixAt, latestAvailableHour } from "@/lib/ned";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const atParam = url.searchParams.get("at");
  const at = atParam ? clampAt(new Date(atParam)) : latestAvailableHour();

  if (Number.isNaN(at.getTime())) {
    return NextResponse.json({ error: "ongeldige datum" }, { status: 400 });
  }

  try {
    const mix = await getMixAt(at);
    const facts = await computeFacts(at, mix);
    return NextResponse.json({ at: at.toISOString(), mix, facts });
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "fout" },
      { status: 500 },
    );
  }
}
