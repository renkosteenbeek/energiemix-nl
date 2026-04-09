"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useDashboardState, type DashboardInitial } from "@/lib/useDashboardState";
import { useTimeScrubber } from "@/lib/useTimeScrubber";
import {
  colorForGreenPct,
  colorForGreenPctSoft,
  type SourceSlice,
  type TimePoint,
} from "@/lib/ned";

const BG = "#FAFAF7";
const INK = "#0B0B0A";
const DIM = "#6B6660";
const DIM2 = "#97928A";
const RULE = "#E6E2D8";
const RULE2 = "#EFEBE0";
const CHIP = "#F2EEE4";
const CHIP_HOVER = "#EAE5D6";
const EMPTY_BAR = "#E0DBCC";

const HOURS_BACK = 24;
const HOURS_FORWARD = 48;

type Jump = { label: string; offsetDays: number; hour: number };

const JUMPS: Jump[] = [
  { label: "Gisteren", offsetDays: -1, hour: 12 },
  { label: "Vannacht", offsetDays: 0, hour: 3 },
  { label: "Ochtend", offsetDays: 0, hour: 9 },
  { label: "Middag", offsetDays: 0, hour: 14 },
  { label: "Avond", offsetDays: 0, hour: 20 },
  { label: "Morgen", offsetDays: 1, hour: 12 },
];

function amsterdamAt(hour: number, offsetDays: number): string {
  const now = new Date();
  const amsHour = parseInt(
    now.toLocaleString("en-US", { hour: "2-digit", hour12: false, timeZone: "Europe/Amsterdam" }),
    10,
  );
  const t = new Date(now);
  t.setUTCHours(t.getUTCHours() + (hour - amsHour) + offsetDays * 24);
  t.setUTCMinutes(0, 0, 0);
  return t.toISOString();
}

function nowHourIso(): string {
  const t = new Date();
  t.setUTCMinutes(0, 0, 0);
  t.setUTCHours(t.getUTCHours() - 1);
  return t.toISOString();
}

function temporalLabel(validfrom: string): string {
  if (!validfrom) return "";
  const t = new Date(validfrom).getTime();
  const now = Date.now();
  const diffMin = Math.round((t - now) / 60000);
  if (Math.abs(diffMin) < 90) return "nu";
  if (diffMin < 0) {
    const h = Math.round(-diffMin / 60);
    if (h < 36) return `${h}\u00a0uur geleden`;
    const d = Math.round(h / 24);
    return `${d}\u00a0dagen geleden`;
  }
  const h = Math.round(diffMin / 60);
  if (h < 36) return `over ${h}\u00a0uur`;
  const d = Math.round(h / 24);
  return `over ${d}\u00a0dagen`;
}

function dayLabel(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nl-NL", {
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Amsterdam",
  });
}

function shortDayLabel(t: Date): string {
  return t
    .toLocaleDateString("nl-NL", { weekday: "short", timeZone: "Europe/Amsterdam" })
    .replace(".", "");
}

function Hero({
  greenPct,
  validfrom,
  loading,
}: {
  greenPct: number;
  validfrom: string;
  loading: boolean;
}) {
  const top = colorForGreenPct(greenPct);
  const bottom = colorForGreenPctSoft(greenPct);
  const rounded = Math.round(greenPct);
  const tlabel = temporalLabel(validfrom);
  const dlabel = dayLabel(validfrom);

  return (
    <section
      className="relative w-full rounded-[28px] overflow-hidden transition-all duration-500"
      style={{
        background: `radial-gradient(130% 110% at 28% 0%, ${top} 0%, ${bottom} 72%, #0a0a0a 140%)`,
        boxShadow: "0 16px 50px -24px rgba(11,11,10,0.25), 0 2px 6px -2px rgba(11,11,10,0.08)",
      }}
    >
      <div className="px-7 pt-8 pb-10 sm:pt-9 sm:pb-11 flex flex-col">
        <div className="flex items-center justify-between">
          <div className="text-[11px] uppercase tracking-[0.2em] text-white/70 first-letter:uppercase">
            {dlabel}
          </div>
          {loading && (
            <div className="w-3 h-3 rounded-full border border-white/50 border-t-transparent animate-spin" />
          )}
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
          duurzaam <span className="text-white/60">· {tlabel}</span>
        </div>
      </div>
    </section>
  );
}

type Bar = {
  iso: string;
  t: Date;
  greenPct: number | null;
  isNow: boolean;
  isMidnightAms: boolean;
  amsterdamHour: number;
  hoursFromNow: number;
};

function DagRitme({
  timeline,
  focusIso,
  onSelect,
}: {
  timeline: TimePoint[];
  focusIso: string;
  onSelect: (iso: string) => void;
}) {
  const { indicatorPct, nowPct, bindings, step, previewIso } = useTimeScrubber({
    focusIso,
    onSelect,
    hoursBack: HOURS_BACK,
    hoursForward: HOURS_FORWARD,
  });

  const nowHour = useMemo(() => {
    const d = new Date();
    d.setUTCMinutes(0, 0, 0);
    return d;
  }, []);

  const bars = useMemo<Bar[]>(() => {
    const byHour = new Map<number, number>();
    for (const p of timeline) {
      byHour.set(new Date(p.time).getTime(), p.greenPct);
    }
    const arr: Bar[] = [];
    for (let i = -HOURS_BACK; i <= HOURS_FORWARD; i++) {
      const t = new Date(nowHour.getTime() + i * 3600000);
      const amsH =
        parseInt(
          t.toLocaleString("en-US", {
            hour: "2-digit",
            hour12: false,
            timeZone: "Europe/Amsterdam",
          }),
          10,
        ) % 24;
      arr.push({
        iso: t.toISOString(),
        t,
        greenPct: byHour.get(t.getTime()) ?? null,
        isNow: i === 0,
        isMidnightAms: amsH === 0,
        amsterdamHour: amsH,
        hoursFromNow: i,
      });
    }
    return arr;
  }, [timeline, nowHour]);

  const dayBoundaries = bars
    .map((bar, i) => ({ bar, i }))
    .filter(({ bar }) => bar.isMidnightAms)
    .map(({ bar, i }) => ({
      pct: i / (bars.length - 1),
      label: shortDayLabel(bar.t),
    }));

  const previewBar = bars.find((b) => b.iso === previewIso);
  const previewLabel = previewBar
    ? previewBar.t.toLocaleString("nl-NL", {
        weekday: "short",
        day: "numeric",
        month: "short",
        hour: "2-digit",
        minute: "2-digit",
        timeZone: "Europe/Amsterdam",
      })
    : "";

  const previewPctValue =
    previewBar?.greenPct != null ? Math.round(previewBar.greenPct) : null;

  return (
    <div className="w-full select-none">
      <div className="flex items-end justify-between mb-4">
        <div>
          <div className="text-[10px] uppercase tracking-[0.26em] mb-1" style={{ color: DIM }}>
            Dagritme
          </div>
          <div className="text-[13px] first-letter:uppercase" style={{ color: INK }}>
            {previewLabel}
            {previewPctValue != null && (
              <>
                <span style={{ color: DIM2 }}> · </span>
                <span
                  className="tabular-nums font-medium"
                  style={{ color: colorForGreenPct(previewPctValue) }}
                >
                  {previewPctValue}%
                </span>
              </>
            )}
          </div>
        </div>
        <div className="flex gap-1">
          <button
            type="button"
            onClick={() => step(-1)}
            className="w-7 h-7 rounded-full flex items-center justify-center text-[12px] cursor-pointer transition-colors"
            style={{ color: INK, border: `1px solid ${RULE}` }}
            aria-label="uur terug"
          >
            ←
          </button>
          <button
            type="button"
            onClick={() => step(1)}
            className="w-7 h-7 rounded-full flex items-center justify-center text-[12px] cursor-pointer transition-colors"
            style={{ color: INK, border: `1px solid ${RULE}` }}
            aria-label="uur vooruit"
          >
            →
          </button>
        </div>
      </div>

      <div className="relative">
        <div
          {...bindings}
          className="relative flex items-end gap-[1.5px] h-[96px] cursor-pointer touch-none"
          style={{ WebkitUserSelect: "none" }}
        >
          {bars.map((bar) => {
            const pct = bar.greenPct ?? 0;
            const hasData = bar.greenPct != null;
            const color = hasData ? colorForGreenPct(pct) : EMPTY_BAR;
            const hMin = 6;
            const hMax = 96;
            const barHeight = hasData ? Math.max(hMin, (pct / 100) * hMax) : hMin;
            return (
              <div
                key={bar.iso}
                className="flex-1 relative flex items-end pointer-events-none"
                style={{ height: "100%" }}
              >
                <div
                  className="w-full transition-[height] duration-300 ease-out"
                  style={{
                    height: `${barHeight}px`,
                    background: color,
                    borderRadius: "1px",
                    opacity: bar.hoursFromNow > 0 ? 0.92 : 1,
                  }}
                />
              </div>
            );
          })}
        </div>

        <div
          className="absolute top-0 bottom-0 pointer-events-none"
          style={{
            left: `${nowPct * 100}%`,
            width: 1,
            background: INK,
            opacity: 0.35,
            transform: "translateX(-0.5px)",
          }}
        />

        <div
          className="absolute pointer-events-none transition-[left] duration-150 ease-out"
          style={{
            left: `${indicatorPct * 100}%`,
            top: -10,
            bottom: -4,
            width: 2,
            background: INK,
            transform: "translateX(-1px)",
          }}
        >
          <div
            className="absolute -left-[3px] -top-[3px]"
            style={{
              width: 8,
              height: 8,
              background: INK,
              borderRadius: "1px",
              transform: "rotate(45deg)",
            }}
          />
        </div>
      </div>

      <div
        className="relative mt-2 pt-2 pb-1 h-[22px]"
        style={{ borderTop: `1px solid ${RULE2}` }}
      >
        {dayBoundaries.map((d) => (
          <div
            key={d.pct}
            className="absolute top-2 text-[9px] uppercase tracking-[0.14em]"
            style={{
              left: `${d.pct * 100}%`,
              transform: "translateX(-50%)",
              color: DIM2,
            }}
          >
            {d.label}
          </div>
        ))}
        <div
          className="absolute top-2 text-[9px] uppercase tracking-[0.14em] font-medium"
          style={{
            left: `${nowPct * 100}%`,
            transform: "translateX(-50%)",
            color: INK,
          }}
        >
          nu
        </div>
      </div>
    </div>
  );
}

function InsightsPills({
  sources,
}: {
  sources: SourceSlice[];
}) {
  const top3 = sources.filter((s) => s.percentage >= 1).slice(0, 3);
  if (top3.length === 0) return null;

  return (
    <div className="flex flex-wrap gap-2">
      {top3.map((s) => (
        <button
          key={s.typeId}
          type="button"
          className="group inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px] cursor-pointer transition-colors duration-150"
          style={{ background: CHIP, border: `1px solid ${RULE}` }}
        >
          <span className="w-1.5 h-1.5 rounded-full" style={{ background: s.color }} />
          <span className="font-medium" style={{ color: INK }}>
            {s.label}
          </span>
          <span className="tabular-nums font-semibold" style={{ color: INK }}>
            {s.percentage.toFixed(0)}%
          </span>
        </button>
      ))}
    </div>
  );
}

function Donut({ sources, total }: { sources: SourceSlice[]; total: number }) {
  const size = 200;
  const stroke = 28;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  let offset = 0;

  const greenSum = sources
    .filter((s) => s.category === "groen")
    .reduce((s, x) => s + x.volumeKWh, 0);
  const greenPct = total > 0 ? Math.round((greenSum / total) * 100) : 0;

  return (
    <div className="relative">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <g transform={`translate(${size / 2}, ${size / 2}) rotate(-90)`}>
          <circle r={r} fill="none" stroke={RULE2} strokeWidth={stroke} />
          {sources.map((s) => {
            const frac = s.volumeKWh / total;
            const len = frac * c;
            const dash = `${len} ${c - len}`;
            const segment = (
              <circle
                key={s.typeId}
                r={r}
                fill="none"
                stroke={s.color}
                strokeWidth={stroke}
                strokeDasharray={dash}
                strokeDashoffset={-offset}
                strokeLinecap="butt"
              />
            );
            offset += len;
            return segment;
          })}
        </g>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <div className="text-3xl font-semibold tabular-nums" style={{ color: INK }}>
          {greenPct}%
        </div>
        <div className="text-[11px] uppercase tracking-[0.18em] mt-0.5" style={{ color: DIM }}>
          groen
        </div>
      </div>
    </div>
  );
}

function AllSources({ sources }: { sources: SourceSlice[] }) {
  const [open, setOpen] = useState(false);
  if (sources.length === 0) return null;
  const total = sources.reduce((sum, s) => sum + s.volumeKWh, 0);
  if (total === 0) return null;

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center justify-between py-3 cursor-pointer transition-opacity hover:opacity-70"
      >
        <span className="text-[10px] uppercase tracking-[0.26em]" style={{ color: DIM }}>
          Alle bronnen
        </span>
        <span
          className="text-sm leading-none transition-transform"
          style={{
            color: DIM2,
            transform: open ? "rotate(90deg)" : "rotate(0deg)",
          }}
        >
          ›
        </span>
      </button>
      {open && (
        <div className="pt-4 pb-2 flex flex-col items-center gap-6">
          <Donut sources={sources} total={total} />
          <ul className="w-full space-y-3 text-[15px]">
            {sources.map((s) => (
              <li key={s.typeId} className="flex items-center gap-3">
                <span
                  className="inline-block w-2.5 h-2.5 rounded-full flex-shrink-0"
                  style={{ background: s.color }}
                />
                <span className="flex-1" style={{ color: INK }}>
                  {s.label}
                </span>
                <span className="tabular-nums text-[13px]" style={{ color: DIM2 }}>
                  {(s.volumeKWh / 1000).toFixed(0)} MWh
                </span>
                <span
                  className="w-14 text-right tabular-nums font-semibold"
                  style={{ color: INK }}
                >
                  {s.percentage.toFixed(0)}%
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

export function Variant({
  initial,
  timeline,
}: {
  initial: DashboardInitial;
  timeline: TimePoint[];
}) {
  const { focusIso, select, snapshot, story, mixLoading, storyLoading } =
    useDashboardState(initial);
  const focusMs = new Date(focusIso).getTime();
  const isNow = Math.abs(focusMs - Date.now()) < 90 * 60 * 1000;

  return (
    <main className="min-h-screen w-full" style={{ background: BG, color: INK }}>
      <div className="max-w-[640px] mx-auto px-5 sm:px-6">
        <header
          className="py-5 flex items-center justify-between"
          style={{ borderBottom: `1px solid ${RULE}` }}
        >
          <Link
            href="/v"
            className="text-[11px] uppercase tracking-[0.2em] transition-opacity hover:opacity-60"
            style={{ color: DIM }}
          >
            ← varianten
          </Link>
          <div className="text-[11px] uppercase tracking-[0.2em]" style={{ color: DIM }}>
            Ritme
          </div>
        </header>

        <div className="pt-6 pb-4">
          <Hero
            greenPct={snapshot.mix.greenPct}
            validfrom={snapshot.mix.focusTime}
            loading={mixLoading}
          />
        </div>

        <section className="pt-8 pb-10" style={{ borderTop: `1px solid ${RULE}` }}>
          <DagRitme timeline={timeline} focusIso={focusIso} onSelect={select} />

          <div className="mt-10 flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => select(nowHourIso())}
              className="px-4 py-2 rounded-full text-[13px] font-medium transition-colors cursor-pointer"
              style={{
                background: isNow ? INK : BG,
                color: isNow ? BG : INK,
                border: `1px solid ${isNow ? INK : RULE}`,
              }}
            >
              Nu
            </button>
            {JUMPS.map((j) => {
              const iso = amsterdamAt(j.hour, j.offsetDays);
              const active = iso === focusIso;
              return (
                <button
                  key={j.label}
                  type="button"
                  onClick={() => select(iso)}
                  className="px-4 py-2 rounded-full text-[13px] cursor-pointer transition-colors"
                  style={{
                    background: active ? INK : BG,
                    color: active ? BG : INK,
                    border: `1px solid ${active ? INK : RULE}`,
                  }}
                >
                  {j.label}
                </button>
              );
            })}
          </div>
        </section>

        <section className="py-10" style={{ borderTop: `1px solid ${RULE}` }}>
          <div className="text-[10px] uppercase tracking-[0.26em] mb-5" style={{ color: DIM }}>
            Duiding
          </div>
          <div className="min-h-[76px]">
            {story && story.length > 0 ? (
              <p
                className="text-[18px] sm:text-[19px] leading-[1.55] font-light text-pretty"
                style={{ color: INK }}
              >
                {story}
                {storyLoading && (
                  <span
                    className="inline-block w-[2px] h-[1.1em] ml-1 -mb-[2px] align-middle animate-pulse"
                    style={{ background: INK, opacity: 0.7 }}
                  />
                )}
              </p>
            ) : storyLoading ? (
              <div className="space-y-2.5">
                <div className="h-3 rounded-full" style={{ background: RULE2, width: "86%" }} />
                <div className="h-3 rounded-full" style={{ background: RULE2, width: "72%" }} />
                <div className="h-3 rounded-full" style={{ background: RULE2, width: "54%" }} />
              </div>
            ) : null}
          </div>
        </section>

        <section className="py-10" style={{ borderTop: `1px solid ${RULE}` }}>
          <div className="text-[10px] uppercase tracking-[0.26em] mb-5" style={{ color: DIM }}>
            Grootste bronnen
          </div>
          <InsightsPills sources={snapshot.facts.sources} />
        </section>

        <section style={{ borderTop: `1px solid ${RULE}` }}>
          <AllSources sources={snapshot.mix.sources} />
        </section>

        <footer
          className="py-8 text-[10px] uppercase tracking-[0.2em] text-center"
          style={{ borderTop: `1px solid ${RULE}`, color: DIM }}
        >
          bron ned.nl
        </footer>
      </div>
    </main>
  );
}
