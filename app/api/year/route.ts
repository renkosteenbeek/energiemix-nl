import { NextResponse } from "next/server";
import { getYear, SOURCES, toAmsterdamDay } from "@/lib/ned";
import { withCors } from "@/lib/responseCache";

const FIRST_YEAR = 2021;

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: withCors({}) });
}

export async function GET(request: Request) {
  const year = Number(new URL(request.url).searchParams.get("year"));
  const currentYear = Number(toAmsterdamDay(new Date()).slice(0, 4));

  if (!Number.isInteger(year) || year < FIRST_YEAR || year > currentYear) {
    return NextResponse.json({ error: "ongeldig jaar" }, { status: 400, headers: withCors({}) });
  }

  try {
    const days = await getYear(year);
    return NextResponse.json(
      {
        year,
        sources: SOURCES.map(({ typeId, label, category }) => ({ typeId, label, category })),
        days,
      },
      {
        headers: withCors({
          "Cache-Control": year < currentYear ? "public, max-age=86400" : "public, max-age=1800",
        }),
      },
    );
  } catch (e) {
    return NextResponse.json(
      { error: e instanceof Error ? e.message : "fout" },
      { status: 500, headers: withCors({}) },
    );
  }
}
