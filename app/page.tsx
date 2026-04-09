import { Dashboard, type DashboardInitial } from "@/components/Dashboard";
import { computeFacts } from "@/lib/insights";
import { describe } from "@/lib/llm";
import { getMixAt, latestAvailableHour } from "@/lib/ned";

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

  return (
    <main className="min-h-screen w-full max-w-[640px] mx-auto px-4 sm:px-6 pt-3 pb-10 flex flex-col gap-6">
{error && (
        <div className="rounded-xl border border-red-900/60 bg-red-950/40 p-4 text-sm text-red-200">
          {error}
        </div>
      )}

      {initial && <Dashboard initial={initial} />}
    </main>
  );
}
