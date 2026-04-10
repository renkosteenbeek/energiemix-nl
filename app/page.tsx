import { isNativeBuild } from "@/lib/api";
import { Dashboard } from "@/components/Dashboard";
import { computeFacts, prefetchBaselines } from "@/lib/insights";
import {
  getGreenTimeline,
  getMixAt,
  latestAvailableHour,
  type TimePoint,
} from "@/lib/ned";
import { theme } from "@/lib/theme";
import type { DashboardInitial } from "@/lib/useDashboardState";

export default async function Page() {
  if (isNativeBuild) {
    return <Dashboard initial={null} timeline={[]} />;
  }

  const { unstable_noStore: noStore } = await import("next/cache");
  noStore();

  const at = latestAvailableHour();
  let initial: DashboardInitial | null = null;
  let timeline: TimePoint[] = [];
  let error: string | null = null;

  try {
    const [mix, rawTimeline] = await Promise.all([
      getMixAt(at),
      getGreenTimeline(new Date(), 720, 24),
      prefetchBaselines(at.getUTCHours()),
    ]);
    timeline = rawTimeline;
    const facts = await computeFacts(at, mix);
    initial = { at: at.toISOString(), mix, facts, story: "" };
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
