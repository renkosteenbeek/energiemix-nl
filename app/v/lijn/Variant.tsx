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
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Amsterdam",
  });
}

const BG = "#FFFFFF";
const INK = "#0A0A0A";
const DIM = "#6B6B6B";
const RULE = "#E5E5E5";
const GREEN = "#2E5E3E";

function LijnScrubber({
  focusIso,
  onSelect,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
}) {
  const { cells, indicatorPct, nowPct, bindings, step, previewIso } = useTimeScrubber({
    focusIso,
    onSelect,
    hoursBack: 36,
    hoursForward: 36,
  });

  const focusCell = cells.find((c) => c.iso === previewIso);
  const focusLabel = focusCell
    ? focusCell.t
        .toLocaleString("nl-NL", {
          weekday: "short",
          day: "numeric",
          month: "short",
          hour: "2-digit",
          minute: "2-digit",
          timeZone: "Europe/Amsterdam",
        })
        .toUpperCase()
    : "";

  const dayLabels = cells
    .filter((c) => c.isMidnightAms)
    .map((c) => ({
      pct: cells.indexOf(c) / (cells.length - 1),
      label: c.t
        .toLocaleDateString("nl-NL", {
          weekday: "short",
          day: "numeric",
          timeZone: "Europe/Amsterdam",
        })
        .toUpperCase(),
    }));

  return (
    <div className="select-none">
      <div
        className="flex items-center justify-between text-[10px] uppercase tracking-[0.22em] mb-5"
        style={{ color: DIM }}
      >
        <button
          type="button"
          onClick={() => step(-1)}
          className="cursor-pointer hover:opacity-60 transition-opacity"
          style={{ color: INK }}
          aria-label="uur terug"
        >
          ← 1 u
        </button>
        <span className="tracking-[0.14em]" style={{ color: INK }}>
          {focusLabel}
        </span>
        <button
          type="button"
          onClick={() => step(1)}
          className="cursor-pointer hover:opacity-60 transition-opacity"
          style={{ color: INK }}
          aria-label="uur vooruit"
        >
          1 u →
        </button>
      </div>
      <div
        {...bindings}
        className="relative h-16 cursor-pointer touch-none"
        style={{ WebkitUserSelect: "none" }}
      >
        <div
          className="absolute left-0 right-0"
          style={{ top: "50%", height: 1, background: INK }}
        />
        {cells.map((cell, i) => {
          const pct = i / (cells.length - 1);
          const big = cell.isMidnightAms;
          const med = cell.amsterdamHour % 6 === 0;
          const h = big ? 12 : med ? 8 : 4;
          return (
            <div
              key={cell.iso}
              className="absolute pointer-events-none"
              style={{ left: `${pct * 100}%`, top: "50%" }}
            >
              <div
                style={{
                  width: 1,
                  height: h,
                  background: INK,
                  opacity: big ? 1 : med ? 0.5 : 0.2,
                  marginLeft: -0.5,
                }}
              />
            </div>
          );
        })}
        {dayLabels.map((d) => (
          <div
            key={d.pct}
            className="absolute pointer-events-none text-[9px] uppercase tracking-[0.14em] -translate-x-1/2"
            style={{ left: `${d.pct * 100}%`, top: "calc(50% + 14px)", color: DIM }}
          >
            {d.label}
          </div>
        ))}
        <div
          className="absolute pointer-events-none -translate-x-1/2"
          style={{ left: `${nowPct * 100}%`, top: "calc(50% - 22px)" }}
        >
          <div className="text-[9px] uppercase tracking-[0.14em]" style={{ color: DIM }}>
            nu
          </div>
        </div>
        <div
          className="absolute pointer-events-none transition-[left] duration-150 ease-out"
          style={{ left: `${indicatorPct * 100}%`, top: "calc(50% - 10px)" }}
        >
          <div
            className="-translate-x-1/2"
            style={{
              width: 0,
              height: 0,
              borderLeft: "6px solid transparent",
              borderRight: "6px solid transparent",
              borderTop: `8px solid ${GREEN}`,
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
  const visibleSources = mix.sources.filter((s) => s.percentage >= 0.5);

  return (
    <main className="min-h-screen w-full" style={{ background: BG, color: INK }}>
      <div className="max-w-[620px] mx-auto px-6 sm:px-8">
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
            Energiemix NL
          </div>
        </header>

        <section className="py-16 sm:py-20">
          <div className="text-[11px] uppercase tracking-[0.26em] first-letter:uppercase mb-6" style={{ color: DIM }}>
            {dayLabel(mix.focusTime)}
          </div>
          <div className="flex items-baseline gap-4">
            <div
              className="tabular-nums leading-[0.82] font-light"
              style={{
                fontSize: "clamp(7rem, 26vw, 16rem)",
                color: GREEN,
                letterSpacing: "-0.05em",
              }}
            >
              {rounded}
            </div>
            <div
              className="tabular-nums font-light"
              style={{ fontSize: "clamp(2rem, 6vw, 4rem)", color: DIM }}
            >
              %
            </div>
          </div>
          <div className="mt-4 text-[20px] sm:text-[22px] font-light tracking-tight" style={{ color: INK }}>
            van de stroom is duurzaam opgewekt.
          </div>
        </section>

        <section
          className="py-12"
          style={{ borderTop: `1px solid ${RULE}` }}
        >
          <div className="text-[10px] uppercase tracking-[0.26em] mb-5" style={{ color: DIM }}>
            Duiding
          </div>
          <div className="min-h-[72px]">
            {story && story.length > 0 ? (
              <p className="text-[19px] leading-[1.55] font-light text-pretty" style={{ color: INK }}>
                {story}
              </p>
            ) : null}
          </div>
        </section>

        <section
          className="py-12"
          style={{ borderTop: `1px solid ${RULE}` }}
        >
          <div className="text-[10px] uppercase tracking-[0.26em] mb-6" style={{ color: DIM }}>
            Bronnen
          </div>
          <ul>
            {visibleSources.map((s, i) => (
              <li
                key={s.typeId}
                className="py-3 flex items-baseline gap-4"
                style={{ borderTop: i === 0 ? "none" : `1px solid ${RULE}` }}
              >
                <span className="text-[15px] tracking-tight flex-1" style={{ color: INK }}>
                  {s.label}
                </span>
                <span className="text-[12px] tabular-nums" style={{ color: DIM }}>
                  {(s.volumeKWh / 1000).toFixed(0)} MWh
                </span>
                <span
                  className="tabular-nums text-[15px] font-medium w-12 text-right"
                  style={{ color: INK }}
                >
                  {s.percentage.toFixed(0)}%
                </span>
              </li>
            ))}
          </ul>
        </section>

        <section
          className="py-12"
          style={{ borderTop: `1px solid ${RULE}` }}
        >
          <div className="text-[10px] uppercase tracking-[0.26em] mb-6" style={{ color: DIM }}>
            Tijdlijn
          </div>
          <LijnScrubber focusIso={focusIso} onSelect={select} />
        </section>

        <section
          className="py-12"
          style={{ borderTop: `1px solid ${RULE}` }}
        >
          <div className="text-[10px] uppercase tracking-[0.26em] mb-5" style={{ color: DIM }}>
            Tijd
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => select(nowHourIso())}
              className="px-4 py-2 text-[13px] transition-colors cursor-pointer rounded-full"
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
                  className="px-4 py-2 text-[13px] transition-colors cursor-pointer rounded-full"
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

        <footer
          className="py-8 text-[11px] uppercase tracking-[0.2em] text-center"
          style={{ borderTop: `1px solid ${RULE}`, color: DIM }}
        >
          bron NED.nl
        </footer>
      </div>
    </main>
  );
}
