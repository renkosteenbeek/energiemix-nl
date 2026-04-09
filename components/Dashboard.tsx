"use client";

import { useCallback, useMemo, useState } from "react";
import {
  colorForGreenPct,
  colorForGreenPctSoft,
  type SourceSlice,
  type TimePoint,
} from "@/lib/ned";
import { theme } from "@/lib/theme";
import {
  amsterdamAt,
  JUMPS,
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
  initial: DashboardInitial;
  timeline: TimePoint[];
}) {
  const { focusIso, select, snapshot, story, mixLoading, storyLoading } =
    useDashboardState(initial);
  const [windowOffset, setWindowOffset] = useState(0);

  const selectAndResetWindow = useCallback(
    (iso: string) => {
      setWindowOffset(0);
      select(iso);
    },
    [select],
  );

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
      <div className="max-w-[640px] mx-auto px-5 sm:px-6">
        <Header mixLoading={mixLoading} />

        <div className="pt-6 pb-4">
          <Hero
            greenPct={snapshot.mix.greenPct}
            validfrom={snapshot.mix.focusTime}
          />
        </div>

        <section className="pt-8 pb-10" style={{ borderTop: `1px solid ${theme.rule}` }}>
          <Timeline
            timeline={timeline}
            focusIso={focusIso}
            onSelect={select}
            windowOffset={windowOffset}
            onPan={panByHours}
          />
          <QuickJumps focusIso={focusIso} onSelect={selectAndResetWindow} />
        </section>

        <section className="py-10" style={{ borderTop: `1px solid ${theme.rule}` }}>
          <SectionLabel>Duiding</SectionLabel>
          <Duiding story={story} loading={storyLoading} />
        </section>

        <section className="py-10" style={{ borderTop: `1px solid ${theme.rule}` }}>
          <SectionLabel>Grootste bronnen</SectionLabel>
          <TopSourcePills sources={snapshot.mix.sources} />
        </section>

        <section className="pb-6" style={{ borderTop: `1px solid ${theme.rule}` }}>
          <AllSources sources={snapshot.mix.sources} />
        </section>
      </div>
    </main>
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
        Energiemix NL
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

function Hero({ greenPct, validfrom }: { greenPct: number; validfrom: string }) {
  const top = colorForGreenPct(greenPct);
  const bottom = colorForGreenPctSoft(greenPct);
  const rounded = Math.round(greenPct);

  return (
    <section
      className="relative w-full rounded-[28px] overflow-hidden transition-all duration-500"
      style={{
        background: `radial-gradient(130% 110% at 28% 0%, ${top} 0%, ${bottom} 72%, #0a0a0a 140%)`,
        boxShadow:
          "0 16px 50px -24px rgba(11,11,10,0.25), 0 2px 6px -2px rgba(11,11,10,0.08)",
      }}
    >
      <div className="px-7 pt-8 pb-10 sm:pt-9 sm:pb-11 flex flex-col">
        <div
          className="text-[11px] uppercase tracking-[0.2em] text-white/70 first-letter:uppercase"
        >
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
      </div>
    </section>
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

function QuickJumps({
  focusIso,
  onSelect,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
}) {
  const referenceNowIso = useMemo(() => nowHourIso(), []);
  const isNow = focusIso === referenceNowIso;

  return (
    <div className="mt-10 flex flex-wrap gap-2">
      <JumpButton active={isNow} onClick={() => onSelect(referenceNowIso)}>
        Nu
      </JumpButton>
      {JUMPS.map((j) => {
        const iso = amsterdamAt(j.hour, j.offsetDays);
        return (
          <JumpButton
            key={j.label}
            active={iso === focusIso}
            onClick={() => onSelect(iso)}
          >
            {j.label}
          </JumpButton>
        );
      })}
    </div>
  );
}

function JumpButton({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="px-4 py-2 rounded-full text-[13px] cursor-pointer transition-colors"
      style={{
        background: active ? theme.ink : theme.bg,
        color: active ? theme.bg : theme.ink,
        border: `1px solid ${active ? theme.ink : theme.rule}`,
        fontWeight: active ? 500 : 400,
      }}
    >
      {children}
    </button>
  );
}
