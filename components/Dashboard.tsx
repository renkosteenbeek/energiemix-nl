"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  colorForGreenPct,
  colorForGreenPctSoft,
  type SourceSlice,
  type TimePoint,
} from "@/lib/ned";
import { apiUrl, isNativeBuild } from "@/lib/api";
import { formatGWh } from "@/lib/format";
import { theme } from "@/lib/theme";
import {
  longDateLabel,
  nowHourIso,
  temporalLabel,
} from "@/lib/time";
import { useDashboardState, type DashboardInitial } from "@/lib/useDashboardState";
import { AllSources } from "./AllSources";
import { Timeline } from "./Timeline";

export function Dashboard({
  initial,
  timeline,
}: {
  initial: DashboardInitial | null;
  timeline: TimePoint[];
}) {
  const { focusIso, select, snapshot, story, mixLoading, storyLoading, refreshTrigger } =
    useDashboardState(initial);
  const [timelineData, setTimelineData] = useState<TimePoint[]>(timeline);
  const [windowOffset, setWindowOffset] = useState(0);
  const nowIso = nowHourIso();
  const isAtNow = focusIso === nowIso;

  useEffect(() => {
    if (timelineData.length > 0 && refreshTrigger === 0) return;
    fetch(apiUrl("/api/timeline"))
      .then((r) => r.json())
      .then((data: TimePoint[]) => {
        if (Array.isArray(data)) setTimelineData(data);
      })
      .catch(() => {});
  }, [refreshTrigger]);

  const jumpToNow = useCallback(() => {
    setWindowOffset(0);
    select(nowHourIso());
  }, [select]);

  const panByHours = useCallback(
    (hours: number) => {
      const newFocus = new Date(
        new Date(focusIso).getTime() + hours * 3600000,
      ).toISOString();
      setWindowOffset((prev) => prev + hours);
      select(newFocus);
    },
    [focusIso, select],
  );

  return (
    <main className="min-h-screen w-full" style={{ background: theme.bg, color: theme.ink }}>
      <div
        className="max-w-[640px] mx-auto px-5 sm:px-6"
        style={{
          paddingTop: "env(safe-area-inset-top)",
          paddingBottom: "calc(4rem + env(safe-area-inset-bottom, 0px))",
        }}
      >
        {!isNativeBuild && <Header mixLoading={mixLoading} />}

        {snapshot ? (
          <>
            <div className="pt-6 pb-4">
              <Hero
                greenPct={snapshot.mix.greenPct}
                validfrom={snapshot.mix.focusTime}
                totalKWh={snapshot.mix.totalKWh}
              />
            </div>

            <section className="pt-8 pb-4">
              <Timeline
                timeline={timelineData}
                focusIso={focusIso}
                onSelect={select}
                windowOffset={windowOffset}
                onPan={panByHours}
                isAtNow={isAtNow}
                onJumpToNow={jumpToNow}
              />
            </section>

            <section className="py-4">
              <SectionLabel>Duiding</SectionLabel>
              <Duiding story={story} loading={storyLoading} />
            </section>

            <section className="py-4">
              <SectionLabel>Grootste bronnen</SectionLabel>
              <TopSourcePills sources={snapshot.mix.sources} />
            </section>

            <section style={{ borderTop: `1px solid ${theme.rule}`, borderBottom: `1px solid ${theme.rule}` }}>
              <AllSources sources={snapshot.mix.sources} />
            </section>
          </>
        ) : (
          <LoadingSkeleton />
        )}
      </div>
    </main>
  );
}

function LoadingSkeleton() {
  return (
    <div className="pt-6 pb-4 space-y-6 animate-pulse">
      <div className="rounded-[28px] h-[280px]" style={{ background: theme.rule2 }} />
      <div className="space-y-3 pt-8">
        <div className="h-3 rounded-full" style={{ background: theme.rule2, width: "70%" }} />
        <div className="h-3 rounded-full" style={{ background: theme.rule2, width: "100%" }} />
        <div className="h-3 rounded-full" style={{ background: theme.rule2, width: "45%" }} />
      </div>
    </div>
  );
}

function Header({ mixLoading }: { mixLoading: boolean }) {
  return (
    <header
      className="py-5 flex items-center justify-between"
      style={{ borderBottom: `1px solid ${theme.rule}` }}
    >
      <div
        className="text-[11px] uppercase tracking-[0.2em]"
        style={{ color: theme.dim }}
      >
        Stroompeil
      </div>
      <div
        className="w-3 h-3 rounded-full border-t-transparent animate-spin transition-opacity duration-200"
        style={{
          border: `1px solid ${theme.dim}`,
          borderTopColor: "transparent",
          opacity: mixLoading ? 0.8 : 0,
        }}
      />
    </header>
  );
}

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="text-[10px] uppercase tracking-[0.26em] mb-5"
      style={{ color: theme.dim }}
    >
      {children}
    </div>
  );
}


function Hero({
  greenPct,
  validfrom,
  totalKWh,
}: {
  greenPct: number;
  validfrom: string;
  totalKWh: number;
}) {
  const [flipped, setFlipped] = useState(false);
  const backRef = useRef<HTMLElement>(null);
  const [backHeight, setBackHeight] = useState(0);
  const top = colorForGreenPct(greenPct);
  const bottom = colorForGreenPctSoft(greenPct);
  const rounded = Math.round(greenPct);

  useEffect(() => {
    if (backRef.current) setBackHeight(backRef.current.scrollHeight);
  }, []);

  return (
    <div className="flip-card">
      <div
        className={`flip-inner ${flipped ? "flipped" : ""}`}
        style={flipped && backHeight ? { minHeight: backHeight } : undefined}
      >
        <section
          className="flip-face relative w-full rounded-[28px] overflow-hidden transition-[background] duration-500"
          style={{
            background: `radial-gradient(130% 110% at 28% 0%, ${top} 0%, ${bottom} 72%, #0a0a0a 140%)`,
            boxShadow:
              "0 16px 50px -24px rgba(11,11,10,0.25), 0 2px 6px -2px rgba(11,11,10,0.08)",
          }}
        >
          <button
            type="button"
            onClick={() => setFlipped(true)}
            className="absolute top-3.5 right-3.5 w-7 h-7 rounded-full flex items-center justify-center text-[12px] italic font-serif text-white/80 cursor-pointer z-10"
            style={{ background: "rgba(255,255,255,0.12)" }}
            aria-label="Over deze app"
          >
            i
          </button>
          <div className="px-7 pt-8 pb-10 sm:pt-9 sm:pb-11 flex flex-col">
            <div className="text-[11px] uppercase tracking-[0.2em] text-white/70 first-letter:uppercase">
              {longDateLabel(validfrom)}
            </div>
            <div className="mt-2 flex items-baseline">
              <div
                className="font-semibold tabular-nums text-white leading-none"
                style={{ fontSize: "clamp(6rem, 32vw, 13rem)", letterSpacing: "-0.05em" }}
              >
                {rounded}
              </div>
              <div
                className="text-white/85 font-light ml-1"
                style={{ fontSize: "clamp(2rem, 7vw, 3.5rem)" }}
              >
                %
              </div>
            </div>
            <div className="mt-1 text-2xl sm:text-[26px] text-white/95 font-light tracking-tight">
              duurzaam{" "}
              <span className="text-white/60">· {temporalLabel(validfrom)}</span>
            </div>
            {totalKWh > 0 && (
              <div className="mt-2 text-[14px] text-white/45 tabular-nums font-light tracking-tight">
                {formatGWh(totalKWh)} verbruik
              </div>
            )}
          </div>
        </section>

        <section
          ref={backRef}
          className="flip-back w-full rounded-[28px] overflow-hidden"
          style={{
            background: "radial-gradient(130% 110% at 28% 0%, #2a2926 0%, #1a1a19 72%, #0a0a0a 140%)",
            boxShadow:
              "0 16px 50px -24px rgba(11,11,10,0.25), 0 2px 6px -2px rgba(11,11,10,0.08)",
          }}
        >
          <button
            type="button"
            onClick={() => setFlipped(false)}
            className="absolute top-3 right-3 w-8 h-8 rounded-full flex items-center justify-center text-[15px] font-light text-white/90 cursor-pointer z-10"
            style={{ background: "rgba(255,255,255,0.15)" }}
            aria-label="Sluiten"
          >
            &times;
          </button>
          <div className="px-7 pt-8 pb-10 sm:pt-9 sm:pb-11 flex flex-col gap-4">
            <div className="text-[10px] uppercase tracking-[0.26em] text-white/50">
              Over Stroompeil
            </div>
            <p className="text-[14px] sm:text-[15px] leading-[1.65] font-light text-white/85">
              Moet ik mijn auto nu opladen, of is de stroom straks groener?
              Die vraag was de aanleiding voor dit project. De bestaande {isNativeBuild ? "apps" : "websites"}
              {" "}vond ik niet mooi genoeg, dus bouwde ik dit zelf.
            </p>
            <p className="text-[14px] sm:text-[15px] leading-[1.65] font-light text-white/85">
              Het grote getal is het percentage groene stroom in Nederland
              op dit moment. Sleep over de tijdlijn om andere uren te
              vergelijken.
            </p>
            <p className="text-[14px] sm:text-[15px] leading-[1.65] font-light text-white/60">
              Data van ned.nl, het platform van de Nederlandse netbeheerders.
            </p>
            <p className="text-[13px] font-light text-white/40">
              Renko Steenbeek
            </p>
          </div>
        </section>
      </div>
    </div>
  );
}

function Duiding({
  story,
  loading,
}: {
  story: string | null;
  loading: boolean;
}) {
  return (
    <div className="min-h-[76px]">
      {story && story.length > 0 ? (
        <p
          className="text-[18px] sm:text-[19px] leading-[1.55] font-light text-pretty"
          style={{ color: theme.ink }}
        >
          {story}
          {loading && (
            <span
              className="inline-block w-[2px] h-[1.1em] ml-1 -mb-[2px] align-middle animate-pulse"
              style={{ background: theme.ink, opacity: 0.7 }}
            />
          )}
        </p>
      ) : loading ? (
        <div className="space-y-2.5">
          <div className="h-3 rounded-full" style={{ background: theme.rule2, width: "86%" }} />
          <div className="h-3 rounded-full" style={{ background: theme.rule2, width: "72%" }} />
          <div className="h-3 rounded-full" style={{ background: theme.rule2, width: "54%" }} />
        </div>
      ) : null}
    </div>
  );
}

function TopSourcePills({ sources }: { sources: SourceSlice[] }) {
  const top3 = sources.filter((s) => s.percentage >= 1).slice(0, 3);
  if (top3.length === 0) return null;

  return (
    <div className="flex flex-wrap gap-2">
      {top3.map((s) => (
        <div
          key={s.typeId}
          className="inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px]"
          style={{ background: theme.chip, border: `1px solid ${theme.rule}` }}
        >
          <span className="w-1.5 h-1.5 rounded-full" style={{ background: s.color }} />
          <span className="font-medium" style={{ color: theme.ink }}>
            {s.label}
          </span>
          <span className="tabular-nums font-semibold" style={{ color: theme.ink }}>
            {s.percentage.toFixed(0)}%
          </span>
        </div>
      ))}
    </div>
  );
}

