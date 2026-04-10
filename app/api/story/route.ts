import { computeFacts } from "@/lib/insights";
import { describe, describeStream } from "@/lib/llm";
import { clampAt, getMixAt, latestAvailableHour } from "@/lib/ned";
import { cacheControl, withCors } from "@/lib/responseCache";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: withCors({}) });
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const atParam = url.searchParams.get("at");
  const at = atParam ? clampAt(new Date(atParam)) : latestAvailableHour();

  if (Number.isNaN(at.getTime())) {
    return new Response(JSON.stringify({ error: "ongeldige datum" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const mix = await getMixAt(at);
    const facts = await computeFacts(at, mix);

    const cached = await describe(facts);
    if (cached) {
      return new Response(cached, {
        headers: withCors({
          "Content-Type": "text/plain; charset=utf-8",
          "Cache-Control": cacheControl(at),
        }),
      });
    }

    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        try {
          for await (const chunk of describeStream(facts)) {
            controller.enqueue(encoder.encode(chunk));
          }
        } catch (err) {
          controller.error(err);
          return;
        }
        controller.close();
      },
    });

    return new Response(stream, {
      headers: withCors({
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": cacheControl(at),
        "X-Accel-Buffering": "no",
      }),
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "fout" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}
