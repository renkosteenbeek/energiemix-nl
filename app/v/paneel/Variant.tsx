"use client";

import Link from "next/link";
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

function dayLabel(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nl-NL", {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Amsterdam",
  });
}

const BG = "#E8E4DC";
const PANEL = "#F5F2EB";
const BORDER = "#C8C2B4";
const INK = "#1A1814";
const DIM = "#766F62";
const RULE = "#DDD7C7";
const GREEN = "#2E5E3E";

const GRAIN_SVG =
  "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.14 0'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")";

function PaneelScrubber({
  focusIso,
  onSelect,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
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
    <div className="px-7 py-5 select-none">
      <div
        className="flex items-center justify-between text-[10px] uppercase tracking-[0.22em] mb-3"
        style={{ color: DIM }}
      >
        <button
          type="button"
          onClick={() => step(-1)}
          className="cursor-pointer hover:opacity-60 transition-opacity"
          style={{ color: INK }}
          aria-label="uur terug"
        >
          ◀
        </button>
        <span className="first-letter:uppercase tracking-[0.16em]" style={{ color: INK }}>
          {focusLabel}
        </span>
        <button
          type="button"
          onClick={() => step(1)}
          className="cursor-pointer hover:opacity-60 transition-opacity"
          style={{ color: INK }}
          aria-label="uur vooruit"
        >
          ▶
        </button>
      </div>
      <div
        {...bindings}
        className="relative h-9 cursor-pointer touch-none rounded-[3px]"
        style={{
          background: "#EEEAE0",
          border: `1px solid ${BORDER}`,
          boxShadow: "inset 0 1px 0 rgba(255,255,255,0.8), inset 0 2px 4px rgba(26,24,20,0.06)",
          WebkitUserSelect: "none",
        }}
      >
        {cells.map((cell, i) => {
          const pct = i / (cells.length - 1);
          const big = cell.isMidnightAms;
          const med = cell.amsterdamHour % 6 === 0;
          const h = big ? 14 : med ? 9 : 4;
          return (
            <div
              key={cell.iso}
              className="absolute pointer-events-none"
              style={{ left: `${pct * 100}%`, top: "50%", transform: "translate(-50%, -50%)" }}
            >
              <div
                style={{
                  width: 1,
                  height: h,
                  background: INK,
                  opacity: big ? 0.7 : med ? 0.45 : 0.22,
                }}
              />
            </div>
          );
        })}
        <div
          className="absolute pointer-events-none"
          style={{ left: `${nowPct * 100}%`, top: "50%", transform: "translate(-50%, -50%)" }}
        >
          <div
            className="rounded-full"
            style={{ width: 3, height: 3, background: GREEN, opacity: 0.9 }}
          />
        </div>
        <div
          className="absolute pointer-events-none transition-[left] duration-150 ease-out"
          style={{ left: `${indicatorPct * 100}%`, top: "50%", transform: "translate(-50%, -50%)" }}
        >
          <div
            className="rounded-[2px]"
            style={{
              width: 3,
              height: 28,
              background: INK,
              boxShadow: "0 0 0 1px rgba(255,255,255,0.9), 0 1px 3px rgba(26,24,20,0.2)",
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
  const rounded = Math.round(mix.greenPct);
  const focusMs = new Date(focusIso).getTime();
  const isNow = Math.abs(focusMs - Date.now()) < 90 * 60 * 1000;
  const top5 = mix.sources.filter((s) => s.percentage >= 1).slice(0, 5);

  return (
    <main
      className="min-h-screen w-full flex items-start justify-center py-10 sm:py-16 px-5"
      style={{
        background: BG,
        backgroundImage: GRAIN_SVG,
        color: INK,
      }}
    >
      <div className="w-full max-w-[560px]">
        <div className="mb-5 flex items-center justify-between">
          <Link
            href="/v"
            className="text-[11px] uppercase tracking-[0.2em] transition-opacity hover:opacity-60"
            style={{ color: DIM }}
          >
            ← varianten
          </Link>
          <div className="text-[11px] uppercase tracking-[0.2em]" style={{ color: DIM }}>
            Energiemix
          </div>
        </div>

        <div
          className="rounded-[6px] overflow-hidden"
          style={{
            background: PANEL,
            border: `1px solid ${BORDER}`,
            boxShadow:
              "inset 0 1px 0 rgba(255,255,255,0.8), inset 0 -1px 0 rgba(0,0,0,0.04), 0 1px 0 rgba(255,255,255,0.6), 0 20px 60px -30px rgba(26,24,20,0.25)",
          }}
        >
          <div className="px-7 pt-5 pb-4 flex items-center justify-between" style={{ borderBottom: `1px solid ${RULE}` }}>
            <div className="text-[10px] uppercase tracking-[0.24em] first-letter:uppercase" style={{ color: DIM }}>
              {dayLabel(mix.focusTime)}
            </div>
            <div className="flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full" style={{ background: GREEN }} />
              <span className="text-[10px] uppercase tracking-[0.18em]" style={{ color: DIM }}>
                live
              </span>
            </div>
          </div>

          <div className="px-7 pt-10 pb-8 flex items-start justify-center">
            <div className="flex items-baseline">
              <div
                className="tabular-nums font-medium leading-none"
                style={{
                  fontSize: "clamp(6rem, 20vw, 10rem)",
                  color: INK,
                  letterSpacing: "-0.045em",
                }}
              >
                {rounded}
              </div>
              <div
                className="font-light ml-1"
                style={{ fontSize: "clamp(2rem, 6vw, 3rem)", color: DIM }}
              >
                %
              </div>
            </div>
          </div>

          <div
            className="px-7 pb-1 text-center"
            style={{ color: GREEN }}
          >
            <div className="text-[11px] uppercase tracking-[0.28em] font-medium">duurzaam</div>
          </div>

          <div className="px-7 py-6 min-h-[78px]" style={{ borderTop: `1px solid ${RULE}`, marginTop: 12 }}>
            {story && story.length > 0 ? (
              <p className="text-[15px] leading-[1.55] font-light text-center" style={{ color: INK }}>
                {story}
              </p>
            ) : null}
          </div>

          <div style={{ borderTop: `1px solid ${RULE}` }}>
            <ul>
              {top5.map((s, i) => (
                <li
                  key={s.typeId}
                  className="px-7 py-3 flex items-center gap-3"
                  style={{ borderTop: i === 0 ? "none" : `1px solid ${RULE}` }}
                >
                  <span
                    className="w-2 h-2 rounded-full flex-shrink-0"
                    style={{ background: s.color }}
                  />
                  <span className="flex-1 text-[13px]" style={{ color: INK }}>
                    {s.label}
                  </span>
                  <span className="tabular-nums text-[13px] font-semibold" style={{ color: INK }}>
                    {s.percentage.toFixed(0)}%
                  </span>
                </li>
              ))}
            </ul>
          </div>

          <div style={{ borderTop: `1px solid ${RULE}` }}>
            <PaneelScrubber focusIso={focusIso} onSelect={select} />
          </div>
        </div>

        <div className="mt-6 flex flex-wrap gap-2 justify-center">
          <button
            type="button"
            onClick={() => select(nowHourIso())}
            className="px-4 py-2 rounded-[4px] text-[12px] font-medium transition-colors cursor-pointer"
            style={{
              background: isNow ? INK : PANEL,
              color: isNow ? PANEL : INK,
              border: `1px solid ${isNow ? INK : BORDER}`,
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
                className="px-4 py-2 rounded-[4px] text-[12px] transition-colors cursor-pointer"
                style={{
                  background: active ? INK : PANEL,
                  color: active ? PANEL : INK,
                  border: `1px solid ${active ? INK : BORDER}`,
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
