"use client";

import Link from "next/link";
import { useDashboardState, type DashboardInitial } from "@/lib/useDashboardState";
import { useTimeScrubber } from "@/lib/useTimeScrubber";
import type { SourceSlice } from "@/lib/ned";

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

function haloPalette(greenPct: number) {
  const t = Math.max(0, Math.min(100, greenPct)) / 100;
  const hue = 28 + (158 - 28) * t;
  return {
    bg: `hsl(${hue}, 52%, 7%)`,
    bgInner: `hsl(${hue}, 48%, 12%)`,
    fg: `hsl(${hue}, 18%, 96%)`,
    ringDim: `hsl(${hue}, 28%, 22%)`,
    dim: `hsl(${hue}, 14%, 62%)`,
    chip: `hsl(${hue}, 32%, 15%)`,
    chipHi: `hsl(${hue}, 38%, 22%)`,
  };
}

function Ring({
  greenPct,
  sources,
  palette,
}: {
  greenPct: number;
  sources: SourceSlice[];
  palette: ReturnType<typeof haloPalette>;
}) {
  const size = 520;
  const stroke = 14;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const total = sources.reduce((s, x) => s + x.volumeKWh, 0);
  let offset = 0;

  return (
    <div
      className="relative"
      style={{ width: size, height: size, maxWidth: "82vmin", maxHeight: "82vmin" }}
    >
      <svg viewBox={`0 0 ${size} ${size}`} className="w-full h-full">
        <defs>
          <radialGradient id="halo-glow" cx="50%" cy="50%" r="50%">
            <stop offset="60%" stopColor={palette.bgInner} stopOpacity="0" />
            <stop offset="100%" stopColor={palette.bgInner} stopOpacity="0.9" />
          </radialGradient>
        </defs>
        <circle cx={size / 2} cy={size / 2} r={r - stroke} fill="url(#halo-glow)" />
        <g transform={`translate(${size / 2}, ${size / 2}) rotate(-90)`}>
          <circle r={r} fill="none" stroke={palette.ringDim} strokeWidth={stroke} />
          {sources.map((s) => {
            const frac = total > 0 ? s.volumeKWh / total : 0;
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
        <div
          className="tabular-nums font-semibold leading-none"
          style={{ fontSize: "clamp(5rem, 22vmin, 12rem)", color: palette.fg, letterSpacing: "-0.04em" }}
        >
          {Math.round(greenPct)}
        </div>
        <div
          className="mt-3 text-[12px] uppercase tracking-[0.28em]"
          style={{ color: palette.dim }}
        >
          procent duurzaam
        </div>
      </div>
    </div>
  );
}

function HaloScrubber({
  focusIso,
  onSelect,
  palette,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
  palette: ReturnType<typeof haloPalette>;
}) {
  const { cells, indicatorPct, nowPct, bindings, step, previewIso } = useTimeScrubber({
    focusIso,
    onSelect,
    hoursBack: 24,
    hoursForward: 24,
  });

  const focusCell = cells.find((c) => c.iso === previewIso);
  const focusLabel = focusCell
    ? focusCell.t.toLocaleString("nl-NL", {
        weekday: "short",
        day: "numeric",
        month: "short",
        hour: "2-digit",
        minute: "2-digit",
        timeZone: "Europe/Amsterdam",
      })
    : "";

  return (
    <div className="w-full max-w-[520px] select-none">
      <div
        className="flex items-center justify-between text-[10px] uppercase tracking-[0.2em] mb-3"
        style={{ color: palette.dim }}
      >
        <button
          type="button"
          onClick={() => step(-1)}
          className="px-2 py-1 cursor-pointer transition-opacity hover:opacity-100"
          style={{ opacity: 0.7 }}
          aria-label="uur terug"
        >
          ← 1 u
        </button>
        <span className="tracking-[0.14em]" style={{ color: palette.fg }}>
          {focusLabel}
        </span>
        <button
          type="button"
          onClick={() => step(1)}
          className="px-2 py-1 cursor-pointer transition-opacity hover:opacity-100"
          style={{ opacity: 0.7 }}
          aria-label="uur vooruit"
        >
          1 u →
        </button>
      </div>
      <div
        {...bindings}
        className="relative h-10 cursor-pointer touch-none"
        style={{ WebkitUserSelect: "none" }}
      >
        <div
          className="absolute left-0 right-0 top-1/2 -translate-y-1/2 h-[1px]"
          style={{ background: palette.ringDim }}
        />
        {cells.map((cell, i) => {
          const pct = i / (cells.length - 1);
          const h = cell.isMidnightAms ? 14 : cell.isNow ? 12 : cell.amsterdamHour % 6 === 0 ? 6 : 3;
          const color = cell.isNow
            ? palette.fg
            : cell.isMidnightAms
              ? palette.dim
              : palette.ringDim;
          return (
            <div
              key={cell.iso}
              className="absolute top-1/2 -translate-y-1/2 pointer-events-none"
              style={{ left: `${pct * 100}%` }}
            >
              <div
                style={{
                  width: 1,
                  height: h,
                  background: color,
                  marginLeft: -0.5,
                  opacity: cell.isNow ? 0.9 : 0.8,
                }}
              />
            </div>
          );
        })}
        <div
          className="absolute top-1/2 -translate-y-1/2 pointer-events-none"
          style={{ left: `${nowPct * 100}%` }}
        >
          <div
            className="rounded-full"
            style={{
              width: 4,
              height: 4,
              background: palette.dim,
              marginLeft: -2,
              opacity: 0.6,
            }}
          />
        </div>
        <div
          className="absolute top-1/2 -translate-y-1/2 pointer-events-none transition-[left] duration-150 ease-out"
          style={{ left: `${indicatorPct * 100}%` }}
        >
          <div
            className="rounded-full"
            style={{
              width: 10,
              height: 10,
              background: palette.fg,
              marginLeft: -5,
              boxShadow: `0 0 16px ${palette.fg}, 0 0 4px ${palette.fg}`,
            }}
          />
        </div>
      </div>
    </div>
  );
}

export function Variant({ initial }: { initial: DashboardInitial }) {
  const { focusIso, select, snapshot, story } = useDashboardState(initial);
  const palette = haloPalette(snapshot.mix.greenPct);
  const top3 = snapshot.facts.sources.filter((s) => s.percentage >= 1).slice(0, 3);
  const focusMs = new Date(focusIso).getTime();
  const isNow = Math.abs(focusMs - Date.now()) < 90 * 60 * 1000;

  return (
    <main
      className="min-h-screen w-full flex flex-col items-center transition-colors duration-500"
      style={{ background: palette.bg, color: palette.fg }}
    >
      <div className="w-full max-w-[720px] px-6 pt-8 pb-16 flex flex-col items-center gap-10">
        <header className="w-full flex items-center justify-between">
          <Link
            href="/v"
            className="text-[12px] uppercase tracking-[0.2em] transition-opacity hover:opacity-100"
            style={{ color: palette.dim, opacity: 0.8 }}
          >
            ← varianten
          </Link>
          <div className="text-[12px] uppercase tracking-[0.18em]" style={{ color: palette.dim }}>
            {dayLabel(snapshot.mix.focusTime)}
          </div>
        </header>

        <div className="flex items-center justify-center py-4">
          <Ring greenPct={snapshot.mix.greenPct} sources={snapshot.mix.sources} palette={palette} />
        </div>

        <div className="min-h-[72px] max-w-[560px] text-center">
          {story && story.length > 0 && (
            <p className="text-[18px] leading-[1.55] font-light text-pretty" style={{ color: palette.fg, opacity: 0.92 }}>
              {story}
            </p>
          )}
        </div>

        {top3.length > 0 && (
          <div className="flex flex-wrap gap-2 justify-center">
            {top3.map((s) => (
              <div
                key={s.typeId}
                className="inline-flex items-center gap-2 rounded-full px-3.5 py-1.5 text-[12px]"
                style={{ background: palette.chip }}
              >
                <span className="w-1.5 h-1.5 rounded-full" style={{ background: s.color }} />
                <span style={{ color: palette.fg }}>{s.label}</span>
                <span className="tabular-nums font-semibold" style={{ color: palette.fg }}>
                  {s.percentage.toFixed(0)}%
                </span>
              </div>
            ))}
          </div>
        )}

        <div className="w-full flex justify-center pt-2">
          <HaloScrubber focusIso={focusIso} onSelect={select} palette={palette} />
        </div>

        <div className="w-full flex flex-wrap gap-2 justify-center">
          <button
            type="button"
            onClick={() => select(nowHourIso())}
            className="px-4 py-2 rounded-full text-[13px] font-medium transition-colors cursor-pointer"
            style={{
              background: isNow ? palette.fg : palette.chip,
              color: isNow ? palette.bg : palette.fg,
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
                className="px-4 py-2 rounded-full text-[13px] transition-colors cursor-pointer"
                style={{
                  background: active ? palette.chipHi : palette.chip,
                  color: palette.fg,
                }}
              >
                {j.label}
              </button>
            );
          })}
        </div>
      </div>
    </main>
  );
}
