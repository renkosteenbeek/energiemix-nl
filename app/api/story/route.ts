import { computeDayFacts, computeFacts } from "@/lib/insights";
import { describeDayStream, describeStream, type DescriptionChunk } from "@/lib/llm";
import { clampAt, DATA_START_DAY, getMixAt, latestAvailableHour, toAmsterdamDay } from "@/lib/ned";
import { cacheControl, errorResponse, failure, optionsResponse, withCors } from "@/lib/http";

const STORY_MAX_AGE_SECONDS = 300;

export function OPTIONS() {
  return optionsResponse();
}

async function streamResponse(chunks: AsyncGenerator<DescriptionChunk>): Promise<Response> {
  const encoder = new TextEncoder();
  const first = await chunks.next();
  const reusable = !first.done && !first.value.isFallback;
  let pending = first.done ? undefined : first.value.text;
  const body = new ReadableStream<Uint8Array>({
    async pull(controller) {
      if (pending !== undefined) {
        controller.enqueue(encoder.encode(pending));
        pending = undefined;
        return;
      }
      try {
        const { value, done } = await chunks.next();
        if (done) {
          controller.close();
        } else {
          controller.enqueue(encoder.encode(value.text));
        }
      } catch (error) {
        controller.error(error);
      }
    },
    async cancel() {
      await chunks.return(undefined);
    },
  });
  return new Response(body, {
    headers: withCors({
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": cacheControl(reusable ? STORY_MAX_AGE_SECONDS : 0),
      "X-Accel-Buffering": "no",
    }),
  });
}

async function dayStory(day: string): Promise<Response> {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || day < DATA_START_DAY || day > toAmsterdamDay(new Date())) {
    return errorResponse(400, "ongeldige dag");
  }
  const facts = await computeDayFacts(day);
  if (!facts) return errorResponse(404, "geen data voor deze dag");
  return streamResponse(describeDayStream(facts));
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  try {
    const day = url.searchParams.get("day");
    if (day) return await dayStory(day);

    const atParam = url.searchParams.get("at");
    const at = atParam ? clampAt(new Date(atParam)) : latestAvailableHour();
    if (Number.isNaN(at.getTime())) return errorResponse(400, "ongeldige datum");

    const facts = await computeFacts(await getMixAt(at));
    return await streamResponse(describeStream(facts));
  } catch (error) {
    return failure(error);
  }
}
