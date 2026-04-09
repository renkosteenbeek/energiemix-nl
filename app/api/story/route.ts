import { computeFacts } from "@/lib/insights";
import { describeStream } from "@/lib/llm";
import { clampAt, getMixAt, latestAvailableHour } from "@/lib/ned";

export const dynamic = "force-dynamic";

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
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-cache, no-transform",
        "X-Accel-Buffering": "no",
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : "fout" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}
