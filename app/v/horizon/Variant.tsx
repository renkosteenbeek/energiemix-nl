"use client";

import Link from "next/link";
import { useMemo } from "react";
import { useDashboardState, type DashboardInitial } from "@/lib/useDashboardState";
import { useTimeScrubber } from "@/lib/useTimeScrubber";

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

function amsterdamHour(iso: string): number {
  return parseInt(
    new Date(iso).toLocaleString("en-US", {
      hour: "2-digit",
      hour12: false,
      timeZone: "Europe/Amsterdam",
    }),
    10,
  );
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

function horizonPalette(greenPct: number, hour: number) {
  const t = Math.max(0, Math.min(100, greenPct)) / 100;

  const isNight = hour < 6 || hour >= 21;
  const isDawn = hour >= 6 && hour < 9;
  const isDusk = hour >= 18 && hour < 21;

  let topHSL: [number, number, number];
  let midHSL: [number, number, number];
  let bottomHSL: [number, number, number];

  if (isNight) {
    topHSL = [230, 35, 10];
    midHSL = [240, 30, 18];
    bottomHSL = [20, 25, 14];
  } else if (isDawn) {
    topHSL = [210, 45, 55];
    midHSL = [25, 70, 72];
    bottomHSL = [15, 65, 52];
  } else if (isDusk) {
    topHSL = [250, 40, 30];
    midHSL = [15, 75, 55];
    bottomHSL = [10, 70, 38];
  } else {
    topHSL = [200 + 10 * t, 55 + 10 * t, 62 + 10 * t];
    midHSL = [160 + 40 * (1 - t), 40, 65];
    bottomHSL = [35 + 10 * (1 - t), 55, 48 + 8 * t];
  }

  const hsl = (arr: [number, number, number]) => `hsl(${arr[0]}, ${arr[1]}%, ${arr[2]}%)`;

  const horizonPos = 30 + 50 * (1 - t);
  const gradient = `linear-gradient(180deg, ${hsl(topHSL)} 0%, ${hsl(midHSL)} ${horizonPos}%, ${hsl(bottomHSL)} 100%)`;

  const darkBg = topHSL[2] < 40;
  const fg = darkBg ? "#FAFAFA" : "#0E0E0E";
  const dim = darkBg ? "rgba(250,250,250,0.66)" : "rgba(20,20,20,0.66)";
  const faint = darkBg ? "rgba(250,250,250,0.22)" : "rgba(20,20,20,0.22)";
  const chip = darkBg ? "rgba(0,0,0,0.35)" : "rgba(255,255,255,0.45)";
  const chipHi = darkBg ? "rgba(0,0,0,0.6)" : "rgba(255,255,255,0.75)";

  return { gradient, fg, dim, faint, chip, chipHi, darkBg, horizonPos };
}

function HorizonScrubber({
  focusIso,
  onSelect,
  palette,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
  palette: ReturnType<typeof horizonPalette>;
}) {
  const { cells, indicatorPct, nowPct, bindings, step, previewIso } = useTimeScrubber({
    focusIso,
    onSelect,
    hoursBack: 36,
    hoursForward: 36,
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
    <div className="w-full select-none">
      <div
        className="flex items-center justify-between mb-2 text-[10px] uppercase tracking-[0.18em]"
        style={{ color: palette.dim }}
      >
        <button
          type="button"
          onClick={() => step(-1)}
          className="cursor-pointer transition-opacity hover:opacity-100"
          style={{ color: palette.fg, opacity: 0.8 }}
          aria-label="uur terug"
        >
          ← 1 u
        </button>
        <span className="first-letter:uppercase tracking-[0.12em]" style={{ color: palette.fg }}>
          {focusLabel}
        </span>
        <button
          type="button"
          onClick={() => step(1)}
          className="cursor-pointer transition-opacity hover:opacity-100"
          style={{ color: palette.fg, opacity: 0.8 }}
          aria-label="uur vooruit"
        >
          1 u →
        </button>
      </div>
      <div
        {...bindings}
        className="relative h-14 cursor-pointer touch-none rounded-full px-3 backdrop-blur-md"
        style={{
          background: palette.chip,
          border: `1px solid ${palette.faint}`,
          WebkitUserSelect: "none",
        }}
      >
        <div
          className="absolute left-3 right-3 top-1/2 -translate-y-1/2 h-[1px]"
          style={{ background: palette.faint }}
        />
        {cells.map((cell, i) => {
          const pct = i / (cells.length - 1);
          const big = cell.isMidnightAms;
          const med = cell.amsterdamHour % 6 === 0;
          const h = big ? 16 : med ? 10 : 5;
          return (
            <div
              key={cell.iso}
              className="absolute top-1/2 -translate-y-1/2 pointer-events-none"
              style={{ left: `calc(12px + ${pct} * (100% - 24px))` }}
            >
              <div
                style={{
                  width: 1,
                  height: h,
                  background: palette.fg,
                  opacity: big ? 0.7 : med ? 0.42 : 0.22,
                  marginLeft: -0.5,
                }}
              />
            </div>
          );
        })}
        <div
          className="absolute top-1/2 -translate-y-1/2 pointer-events-none"
          style={{ left: `calc(12px + ${nowPct} * (100% - 24px))` }}
        >
          <div
            className="rounded-full"
            style={{
              width: 4,
              height: 4,
              background: palette.fg,
              opacity: 0.55,
              marginLeft: -2,
            }}
          />
        </div>
        <div
          className="absolute top-1/2 -translate-y-1/2 pointer-events-none transition-[left] duration-150 ease-out"
          style={{ left: `calc(12px + ${indicatorPct} * (100% - 24px))` }}
        >
          <div
            className="rounded-full"
            style={{
              width: 14,
              height: 14,
              background: palette.fg,
              marginLeft: -7,
              boxShadow: palette.darkBg
                ? "0 0 24px rgba(255,255,255,0.55), 0 0 6px rgba(255,255,255,0.7)"
                : "0 0 24px rgba(0,0,0,0.35), 0 0 6px rgba(0,0,0,0.4)",
            }}
          />
        </div>
      </div>
    </div>
  );
}

export function Variant({ initial }: { initial: DashboardInitial }) {
  const { focusIso, select, snapshot, story } = useDashboardState(initial);
  const { mix } = snapshot;
  const hour = amsterdamHour(mix.focusTime);
  const palette = useMemo(
    () => horizonPalette(mix.greenPct, hour),
    [mix.greenPct, hour],
  );
  const rounded = Math.round(mix.greenPct);
  const focusMs = new Date(focusIso).getTime();
  const isNow = Math.abs(focusMs - Date.now()) < 90 * 60 * 1000;

  let cumulative = 0;
  const strata = mix.sources
    .filter((s) => s.percentage >= 2)
    .slice(0, 6)
    .map((s) => {
      cumulative += s.percentage;
      return { ...s, topPct: cumulative };
    });

  return (
    <main
      className="min-h-screen w-full relative overflow-hidden transition-all duration-700"
      style={{ background: palette.gradient, color: palette.fg }}
    >
      <div
        className="absolute left-0 right-0 pointer-events-none"
        style={{
          top: `${palette.horizonPos}%`,
          height: "1px",
          background: palette.faint,
        }}
      />

      <div className="relative min-h-screen flex flex-col">
        <header className="px-8 sm:px-12 pt-10 flex items-center justify-between">
          <Link
            href="/v"
            className="text-[11px] uppercase tracking-[0.2em] transition-opacity hover:opacity-100"
            style={{ color: palette.dim }}
          >
            ← varianten
          </Link>
          <div className="text-[11px] uppercase tracking-[0.2em] first-letter:uppercase" style={{ color: palette.dim }}>
            {dayLabel(mix.focusTime)}
          </div>
        </header>

        <div className="flex-1 relative px-8 sm:px-12 py-12">
          <div className="absolute right-8 sm:right-12 top-6 bottom-28 flex flex-col justify-between items-end text-right max-w-[220px]">
            {strata.map((s) => (
              <div key={s.typeId} className="flex items-center gap-3">
                <div
                  className="text-[11px] uppercase tracking-[0.14em]"
                  style={{ color: palette.dim }}
                >
                  {s.label}
                </div>
                <div
                  className="tabular-nums text-[13px] font-semibold"
                  style={{ color: palette.fg }}
                >
                  {s.percentage.toFixed(0)}%
                </div>
                <div
                  className="w-12 h-[1px]"
                  style={{ background: s.color, opacity: 0.75 }}
                />
              </div>
            ))}
          </div>

          <div className="absolute left-8 sm:left-12 bottom-36">
            <div className="flex items-baseline gap-3">
              <div
                className="tabular-nums font-light leading-[0.85]"
                style={{
                  fontSize: "clamp(7rem, 28vw, 18rem)",
                  color: palette.fg,
                  letterSpacing: "-0.05em",
                }}
              >
                {rounded}
              </div>
              <div
                className="font-light"
                style={{ fontSize: "clamp(2rem, 6vw, 4rem)", color: palette.dim }}
              >
                %
              </div>
            </div>
            <div
              className="mt-1 text-[14px] tracking-[0.02em]"
              style={{ color: palette.dim }}
            >
              duurzaam
            </div>
          </div>
        </div>

        <div className="px-8 sm:px-12 pb-8">
          <div className="max-w-[560px] min-h-[60px] mb-6">
            {story && story.length > 0 && (
              <p
                className="text-[16px] leading-[1.55] font-light"
                style={{ color: palette.fg, opacity: 0.92 }}
              >
                {story}
              </p>
            )}
          </div>

          <div className="mb-5">
            <HorizonScrubber focusIso={focusIso} onSelect={select} palette={palette} />
          </div>

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => select(nowHourIso())}
              className="px-4 py-2 rounded-full text-[12px] backdrop-blur-md transition-colors cursor-pointer"
              style={{
                background: isNow ? palette.chipHi : palette.chip,
                color: palette.fg,
                border: `1px solid ${palette.faint}`,
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
                  className="px-4 py-2 rounded-full text-[12px] backdrop-blur-md transition-colors cursor-pointer"
                  style={{
                    background: active ? palette.chipHi : palette.chip,
                    color: palette.fg,
                    border: `1px solid ${palette.faint}`,
                  }}
                >
                  {j.label}
                </button>
              );
            })}
          </div>
        </div>
      </div>
    </main>
  );
}
