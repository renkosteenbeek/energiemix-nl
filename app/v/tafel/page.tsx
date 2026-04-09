import { computeFacts } from "@/lib/insights";
import { describe } from "@/lib/llm";
import { getMixAt, latestAvailableHour } from "@/lib/ned";
import type { DashboardInitial } from "@/lib/useDashboardState";
import { Variant } from "./Variant";

export const dynamic = "force-dynamic";

export default async function Page() {
  const at = latestAvailableHour();
  let initial: DashboardInitial | null = null;
  let error: string | null = null;

  try {
    const mix = await getMixAt(at);
    const facts = await computeFacts(at, mix);
    let story = "";
    try {
      story = await Promise.race([
        describe(facts),
        new Promise<string>((resolve) => setTimeout(() => resolve(""), 1500)),
      ]);
    } catch {
      story = "";
    }
    initial = { at: at.toISOString(), mix, facts, story };
  } catch (e) {
    error = e instanceof Error ? e.message : "Onbekende fout";
  }

  if (error || !initial) {
    return (
      <main className="min-h-screen bg-[#FAF8F3] text-red-700 flex items-center justify-center p-8">
        <div>{error ?? "Geen data"}</div>
      </main>
    );
  }

  return <Variant initial={initial} />;
}
