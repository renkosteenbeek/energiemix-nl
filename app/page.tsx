import { Dashboard } from "@/components/Dashboard";
import { computeFacts } from "@/lib/insights";
import { describe } from "@/lib/llm";
import {
  getGreenTimeline,
  getMixAt,
  latestAvailableHour,
  type TimePoint,
} from "@/lib/ned";
import { theme } from "@/lib/theme";
import type { DashboardInitial } from "@/lib/useDashboardState";

export const dynamic = "force-dynamic";

export default async function Page() {
  const at = latestAvailableHour();
  let initial: DashboardInitial | null = null;
  let timeline: TimePoint[] = [];
  let error: string | null = null;

  try {
    const [mix, rawTimeline] = await Promise.all([
      getMixAt(at),
      getGreenTimeline(new Date(), 48, 48),
    ]);
    timeline = rawTimeline;
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
      <main
        className="min-h-screen flex items-center justify-center p-8"
        style={{ background: theme.bg, color: "#B91C1C" }}
      >
        <div>{error ?? "Geen data"}</div>
      </main>
    );
  }

  return <Dashboard initial={initial} timeline={timeline} />;
}
