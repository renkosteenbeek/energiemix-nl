"use client";

import Link from "next/link";
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { useDashboardState, type DashboardInitial } from "@/lib/useDashboardState";
import { colorForGreenPct, colorForGreenPctSoft, type SourceSlice } from "@/lib/ned";

const BG = "#FAFAFA";
const INK = "#0A0A0A";
const DIM = "#6B6B6B";
const DIM2 = "#9A9A9A";
const RULE = "#E5E5E5";
const RULE2 = "#EDEDED";
const CHIP = "#F0F0F0";
const CHIP_HOVER = "#E6E6E6";

const HOURS_BACK = 72;
const HOURS_FORWARD = 96;
const CELL_WIDTH = 64;
const HALF_CELL = CELL_WIDTH / 2;

function startOfHourUTC(d: Date): Date {
  const out = new Date(d);
  out.setUTCMinutes(0, 0, 0);
  return out;
}

function fmtHour(d: Date): string {
  return d.toLocaleTimeString("nl-NL", {
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Amsterdam",
  });
}

function fmtDay(d: Date): { weekday: string; date: string } {
  return {
    weekday: d.toLocaleDateString("nl-NL", { weekday: "short", timeZone: "Europe/Amsterdam" }),
    date: d.toLocaleDateString("nl-NL", { day: "numeric", month: "short", timeZone: "Europe/Amsterdam" }),
  };
}

function localHourInAmsterdam(d: Date): number {
  return parseInt(
    d.toLocaleString("en-US", { hour: "2-digit", hour12: false, timeZone: "Europe/Amsterdam" }),
    10,
  ) % 24;
}

const useIsoLayoutEffect = typeof window !== "undefined" ? useLayoutEffect : useEffect;

function HourStripLight({
  focusIso,
  onSelect,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
}) {
  const scrollerRef = useRef<HTMLDivElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const programmaticUntilRef = useRef(0);

  const focusDate = useMemo(() => startOfHourUTC(new Date(focusIso)), [focusIso]);
  const nowHour = useMemo(() => startOfHourUTC(new Date()), []);

  const cells = useMemo(() => {
    const arr: { t: Date; isNow: boolean }[] = [];
    for (let i = -HOURS_BACK; i <= HOURS_FORWARD; i++) {
      const t = new Date(nowHour.getTime() + i * 60 * 60 * 1000);
      arr.push({ t, isNow: i === 0 });
    }
    return arr;
  }, [nowHour]);

  const focusIndex = useMemo(() => {
    const target = focusDate.getTime();
    let best = 0;
    let bestDiff = Infinity;
    for (let i = 0; i < cells.length; i++) {
      const d = Math.abs(cells[i].t.getTime() - target);
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }, [cells, focusDate]);

  useIsoLayoutEffect(() => {
    const el = scrollerRef.current;
    if (!el) return;
    const target = focusIndex * CELL_WIDTH;
    if (Math.abs(el.scrollLeft - target) < 2) return;
    programmaticUntilRef.current = Date.now() + 400;
    el.scrollLeft = target;
  }, [focusIndex]);

  const onScroll = () => {
    if (Date.now() < programmaticUntilRef.current) return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      const el = scrollerRef.current;
      if (!el) return;
      const idx = Math.round(el.scrollLeft / CELL_WIDTH);
      const cell = cells[Math.max(0, Math.min(cells.length - 1, idx))];
      if (!cell) return;
      const iso = cell.t.toISOString();
      if (iso === focusIso) return;
      onSelect(iso);
    }, 180);
  };

  return (
    <div className="relative w-full">
      <div
        className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-10 rounded-2xl"
        style={{
          width: CELL_WIDTH + 4,
          height: 76,
          background: "rgba(0,0,0,0.04)",
          border: "1px solid rgba(0,0,0,0.14)",
        }}
      />
      <div
        ref={scrollerRef}
        onScroll={onScroll}
        className="overflow-x-auto overflow-y-hidden scrollbar-hide"
        style={{
          scrollSnapType: "x mandatory",
          WebkitOverflowScrolling: "touch",
          paddingInline: `calc(50% - ${HALF_CELL}px)`,
          maskImage: "linear-gradient(90deg, transparent 0, black 14%, black 86%, transparent 100%)",
        }}
      >
        <div className="flex" style={{ height: 96 }}>
          {cells.map((cell, i) => {
            const showDay = localHourInAmsterdam(cell.t) === 0 || i === 0;
            const day = showDay ? fmtDay(cell.t) : null;
            const hour = fmtHour(cell.t);
            const iso = cell.t.toISOString();
            const isFocus = i === focusIndex;
            return (
              <button
                key={iso}
                type="button"
                onClick={(e) => {
                  e.preventDefault();
                  if (iso === focusIso) return;
                  onSelect(iso);
                }}
                className="flex-shrink-0 flex flex-col items-center justify-end pb-3 relative select-none touch-manipulation cursor-pointer"
                style={{ width: CELL_WIDTH, scrollSnapAlign: "center" }}
              >
                {day && (
                  <div className="absolute top-0 left-0 right-0 text-center text-[10px] uppercase tracking-wider leading-tight">
                    <div style={{ color: "#555" }}>{day.weekday}</div>
                    <div style={{ color: "#9A9A9A" }}>{day.date}</div>
                  </div>
                )}
                <div
                  className="text-[15px] tabular-nums transition-colors"
                  style={{
                    color: isFocus
                      ? INK
                      : cell.isNow
                        ? "#2A2A2A"
                        : "#9A9A9A",
                    fontWeight: isFocus ? 600 : cell.isNow ? 500 : 400,
                  }}
                >
                  {hour}
                </div>
                <div
                  className="mt-1.5 rounded-full transition-all"
                  style={{
                    width: isFocus ? 8 : cell.isNow ? 6 : 4,
                    height: isFocus ? 8 : cell.isNow ? 6 : 4,
                    background: isFocus ? INK : cell.isNow ? "#555" : "#CCC",
                  }}
                />
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}

type Jump = { label: string; offsetDays: number; hour: number };

const JUMPS: Jump[] = [
  { label: "Gisteren", offsetDays: -1, hour: 12 },
  { label: "Vannacht", offsetDays: 0, hour: 3 },
  { label: "Ochtend", offsetDays: 0, hour: 9 },
  { label: "Middag", offsetDays: 0, hour: 14 },
  { label: "Avond", offsetDays: 0, hour: 20 },
  { label: "Morgen", offsetDays: 1, hour: 12 },
  { label: "Overmorgen", offsetDays: 2, hour: 12 },
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

function QuickJumpLight({
  focusIso,
  onSelect,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
}) {
  const focusMs = new Date(focusIso).getTime();
  const isNow = Math.abs(focusMs - Date.now()) < 90 * 60 * 1000;

  return (
    <div className="w-full overflow-x-auto scrollbar-hide -mx-4 px-4">
      <div className="flex gap-2 min-w-max">
        <button
          type="button"
          onClick={() => onSelect(nowHourIso())}
          className="px-4 py-2.5 rounded-full text-[15px] font-medium transition-colors flex-shrink-0 select-none touch-manipulation cursor-pointer"
          style={
            isNow
              ? { background: INK, color: BG }
              : { background: CHIP, color: INK, border: `1px solid ${RULE}` }
          }
        >
          Nu
        </button>
        {JUMPS.map((j) => (
          <button
            key={j.label}
            type="button"
            onClick={() => onSelect(amsterdamAt(j.hour, j.offsetDays))}
            className="px-4 py-2.5 rounded-full text-[15px] flex-shrink-0 select-none touch-manipulation cursor-pointer transition-colors"
            style={{ background: CHIP, color: INK, border: `1px solid ${RULE}` }}
          >
            {j.label}
          </button>
        ))}
      </div>
    </div>
  );
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

function dayLabel(validfrom: string): string {
  if (!validfrom) return "";
  return new Date(validfrom).toLocaleString("nl-NL", {
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Amsterdam",
  });
}

function HeroLight({
  greenPct,
  validfrom,
}: {
  greenPct: number;
  validfrom: string;
}) {
  const top = colorForGreenPct(greenPct);
  const bottom = colorForGreenPctSoft(greenPct);
  const rounded = Math.round(greenPct);
  const tlabel = temporalLabel(validfrom);
  const dlabel = dayLabel(validfrom);

  return (
    <section
      className="relative w-full rounded-[32px] overflow-hidden"
      style={{
        background: `radial-gradient(120% 100% at 30% 0%, ${top} 0%, ${bottom} 70%, #0a0a0a 130%)`,
        boxShadow: "0 10px 40px -20px rgba(0,0,0,0.15)",
      }}
    >
      <div className="px-6 pt-7 pb-9 sm:pt-10 sm:pb-12 flex flex-col">
        <div className="text-[11px] uppercase tracking-[0.18em] text-white/70 first-letter:uppercase">
          {dlabel}
        </div>
        <div className="mt-1 flex items-baseline">
          <div
            className="font-semibold tabular-nums text-white leading-none tracking-tighter"
            style={{ fontSize: "clamp(7rem, 38vw, 16rem)" }}
          >
            {rounded}
          </div>
          <div
            className="text-white/85 font-medium ml-1"
            style={{ fontSize: "clamp(2rem, 8vw, 4rem)" }}
          >
            %
          </div>
        </div>
        <div className="mt-1 text-2xl sm:text-3xl text-white/95 font-light tracking-tight">
          duurzaam <span className="text-white/65">· {tlabel}</span>
        </div>
      </div>
    </section>
  );
}

function InsightsLight({
  story,
  sources,
}: {
  story: string | null;
  sources: SourceSlice[];
}) {
  const top3 = sources.filter((s) => s.percentage >= 1).slice(0, 3);

  return (
    <section className="w-full px-1">
      <div className="min-h-[88px]">
        {story && story.length > 0 && (
          <p className="text-[19px] sm:text-xl text-neutral-900 leading-[1.45] font-light text-pretty">
            {story}
          </p>
        )}
      </div>
      {top3.length > 0 && (
        <>
          <div className="mt-5 flex flex-wrap gap-2">
            {top3.map((s) => {
              return (
                <button
                  key={s.typeId}
                  type="button"
                  className="group inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[13px] cursor-pointer transition-colors duration-150"
                  style={{ background: CHIP, border: `1px solid ${RULE}` }}
                >
                  <span
                    className="w-1.5 h-1.5 rounded-full"
                    style={{ background: s.color }}
                  />
                  <span className="text-neutral-800 font-medium">{s.label}</span>
                  <span className="tabular-nums font-semibold" style={{ color: INK }}>
                    {s.percentage.toFixed(0)}%
                  </span>
                </button>
              );
            })}
          </div>
          <p className="mt-3 text-[11px] leading-relaxed" style={{ color: DIM2 }}>
            &ldquo;Normaal&rdquo; is het gemiddelde voor ditzelfde uur van de dag over de
            afgelopen 30 dagen.
          </p>
        </>
      )}
    </section>
  );
}

function DonutLight({ sources, total }: { sources: SourceSlice[]; total: number }) {
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
          <circle r={r} fill="none" stroke="#EEE" strokeWidth={stroke} />
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
        <div className="text-[11px] uppercase tracking-wider mt-0.5" style={{ color: DIM2 }}>
          groen
        </div>
      </div>
    </div>
  );
}

function SourcesDetailLight({ sources }: { sources: SourceSlice[] }) {
  const [open, setOpen] = useState(false);
  if (sources.length === 0) return null;
  const total = sources.reduce((sum, s) => sum + s.volumeKWh, 0);
  if (total === 0) return null;

  return (
    <div
      className="w-full rounded-2xl"
      style={{ background: "#FFFFFF", border: `1px solid ${RULE}` }}
    >
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="w-full flex items-center justify-between px-5 py-4 cursor-pointer rounded-2xl transition-colors"
        style={{ color: "#2A2A2A" }}
      >
        <span className="text-[15px] font-medium">Alle bronnen</span>
        <span
          className="text-lg leading-none transition-transform"
          style={{
            color: DIM2,
            transform: open ? "rotate(90deg)" : "rotate(0deg)",
          }}
        >
          ›
        </span>
      </button>
      {open && (
        <div className="px-5 pb-5 pt-1 flex flex-col items-center gap-6">
          <DonutLight sources={sources} total={total} />
          <ul className="w-full space-y-3 text-[15px]">
            {sources.map((s) => (
              <li key={s.typeId} className="flex items-center gap-3">
                <span
                  className="inline-block w-2.5 h-2.5 rounded-full flex-shrink-0"
                  style={{ background: s.color }}
                />
                <span className="flex-1" style={{ color: "#1A1A1A" }}>
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

export function Variant({ initial }: { initial: DashboardInitial }) {
  const { focusIso, select, snapshot, story } = useDashboardState(initial);

  return (
    <main
      className="min-h-screen w-full"
      style={{ background: BG, color: INK }}
    >
      <div className="w-full max-w-[640px] mx-auto px-4 sm:px-6 pt-3 pb-10 flex flex-col gap-6">
        <div className="flex items-center justify-between pt-1">
          <Link
            href="/v"
            className="text-[11px] uppercase tracking-[0.2em] transition-opacity hover:opacity-60"
            style={{ color: DIM }}
          >
            ← varianten
          </Link>
          <div className="text-[11px] uppercase tracking-[0.18em]" style={{ color: DIM }}>
            Energiemix NL
          </div>
        </div>

        <HeroLight
          greenPct={snapshot.mix.greenPct}
          validfrom={snapshot.mix.focusTime}
        />

        <div className="flex flex-col gap-3">
          <HourStripLight focusIso={focusIso} onSelect={select} />
          <QuickJumpLight focusIso={focusIso} onSelect={select} />
        </div>

        <InsightsLight story={story} sources={snapshot.facts.sources} />

        <SourcesDetailLight sources={snapshot.mix.sources} />
      </div>
    </main>
  );
}
