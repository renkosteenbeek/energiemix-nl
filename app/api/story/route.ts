import { computeDayFacts, computeFacts } from "@/lib/insights";
import { cachedDayDescription, cachedDescription, describeDayStream, describeStream } from "@/lib/llm";
import { clampAt, DAILY_MIN_DAY, getMixAt, latestAvailableHour, toAmsterdamDay } from "@/lib/ned";
import { cacheControl, withCors } from "@/lib/responseCache";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: withCors({}) });
}

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: withCors({ "Content-Type": "application/json" }),
  });
}

function textResponse(body: string | ReadableStream<Uint8Array>, cache: string): Response {
  return new Response(body, {
    headers: withCors({
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": cache,
      "X-Accel-Buffering": "no",
    }),
  });
}

function streamOf(chunks: AsyncGenerator<string>): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  return new ReadableStream<Uint8Array>({
    async pull(controller) {
      const { value, done } = await chunks.next();
      if (done) {
        controller.close();
      } else {
        controller.enqueue(encoder.encode(value));
      }
    },
    async cancel() {
      await chunks.return(undefined);
    },
  });
}

async function dayStory(day: string): Promise<Response> {
  const today = toAmsterdamDay(new Date());
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || day < DAILY_MIN_DAY || day > today) {
    return errorResponse(400, "ongeldige dag");
  }
  const facts = await computeDayFacts(day);
  if (!facts) return errorResponse(404, "geen data voor deze dag");
  const cache = day === today ? "public, max-age=900" : "public, max-age=86400";
  const cached = cachedDayDescription(facts);
  return textResponse(cached ?? streamOf(describeDayStream(facts)), cache);
}

export async function GET(request: Request) {
  const url = new URL(request.url);

  try {
    const dayParam = url.searchParams.get("day");
    if (dayParam) return await dayStory(dayParam);

    const atParam = url.searchParams.get("at");
    const at = atParam ? clampAt(new Date(atParam)) : latestAvailableHour();
    if (Number.isNaN(at.getTime())) return errorResponse(400, "ongeldige datum");

    const mix = await getMixAt(at);
    const facts = await computeFacts(at, mix);
    const cached = cachedDescription(facts);
    return textResponse(cached ?? streamOf(describeStream(facts)), cacheControl(at));
  } catch (e) {
    return errorResponse(500, e instanceof Error ? e.message : "fout");
  }
}
