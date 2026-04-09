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

function formatDay(iso: string): string {
  if (!iso) return "";
  return new Date(iso)
    .toLocaleString("nl-NL", {
      weekday: "long",
      day: "numeric",
      month: "long",
      hour: "2-digit",
      minute: "2-digit",
      timeZone: "Europe/Amsterdam",
    })
    .toUpperCase();
}

const BG = "#FAF8F3";
const INK = "#151414";
const DIM = "#6B6761";
const RULE = "#E5E1D7";
const GREEN = "#2E5E3E";

function TafelScrubber({
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

  return (
    <div className="max-w-[560px] select-none">
      <div
        className="flex items-center justify-between text-[10px] uppercase tracking-[0.22em] mb-4"
        style={{ color: DIM }}
      >
        <button
          type="button"
          onClick={() => step(-1)}
          className="cursor-pointer hover:opacity-60 transition-opacity"
          aria-label="uur terug"
          style={{ color: INK }}
        >
          ← 1 u
        </button>
        <span style={{ color: INK }} className="tabular-nums tracking-[0.14em]">
          {focusLabel}
        </span>
        <button
          type="button"
          onClick={() => step(1)}
          className="cursor-pointer hover:opacity-60 transition-opacity"
          aria-label="uur vooruit"
          style={{ color: INK }}
        >
          1 u →
        </button>
      </div>
      <div
        {...bindings}
        className="relative h-12 cursor-pointer touch-none"
        style={{ WebkitUserSelect: "none" }}
      >
        <div
          className="absolute left-0 right-0"
          style={{ top: "50%", height: 1, background: INK, opacity: 0.85 }}
        />
        {cells.map((cell, i) => {
          const pct = i / (cells.length - 1);
          const big = cell.isMidnightAms;
          const med = cell.amsterdamHour % 6 === 0;
          const h = big ? 14 : med ? 9 : 5;
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
                  opacity: big ? 0.85 : med ? 0.55 : 0.3,
                  marginLeft: -0.5,
                }}
              />
            </div>
          );
        })}
        <div
          className="absolute pointer-events-none"
          style={{ left: `${nowPct * 100}%`, top: "calc(50% + 14px)" }}
        >
          <div
            className="text-[9px] uppercase tracking-[0.14em] -translate-x-1/2"
            style={{ color: DIM }}
          >
            nu
          </div>
        </div>
        <div
          className="absolute pointer-events-none transition-[left] duration-150 ease-out"
          style={{ left: `${indicatorPct * 100}%`, top: "calc(50% - 16px)" }}
        >
          <div
            className="-translate-x-1/2"
            style={{
              width: 0,
              height: 0,
              borderLeft: "7px solid transparent",
              borderRight: "7px solid transparent",
              borderTop: `9px solid ${GREEN}`,
            }}
          />
        </div>
      </div>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div
      className="grid gap-4 sm:gap-8 py-6 sm:py-8 items-baseline"
      style={{ borderTop: `1px solid ${RULE}`, gridTemplateColumns: "minmax(90px, 120px) 1fr" }}
    >
      <div className="text-[10px] uppercase tracking-[0.22em] pt-1.5" style={{ color: DIM }}>
        {label}
      </div>
      <div>{children}</div>
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
      <div className="max-w-[760px] mx-auto px-6 sm:px-10 pt-16 pb-24">
        <header className="flex items-center justify-between mb-12">
          <Link
            href="/v"
            className="text-[11px] uppercase tracking-[0.22em] transition-opacity hover:opacity-60"
            style={{ color: DIM }}
          >
            ← varianten
          </Link>
          <div className="text-[11px] uppercase tracking-[0.22em]" style={{ color: DIM }}>
            Energiemix NL
          </div>
        </header>

        <Row label="Moment">
          <div className="text-[14px] tracking-[0.06em]" style={{ color: INK }}>
            {formatDay(mix.focusTime)}
          </div>
        </Row>

        <Row label="Duurzaam">
          <div className="flex items-baseline gap-4">
            <div
              className="tabular-nums leading-[0.85] font-semibold"
              style={{
                fontSize: "clamp(6rem, 22vw, 14rem)",
                color: GREEN,
                letterSpacing: "-0.04em",
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
        </Row>

        <Row label="Duiding">
          <div className="min-h-[64px] max-w-[580px]">
            {story && story.length > 0 ? (
              <p className="text-[17px] leading-[1.55] font-light" style={{ color: INK }}>
                {story}
              </p>
            ) : (
              <p className="text-[14px]" style={{ color: DIM }}>
                ...
              </p>
            )}
          </div>
        </Row>

        <Row label="Bronnen">
          <ul className="space-y-3 max-w-[520px]">
            {visibleSources.map((s) => (
              <li key={s.typeId} className="flex items-baseline gap-3">
                <span className="text-[15px] tracking-tight" style={{ color: INK }}>
                  {s.label}
                </span>
                <span
                  className="flex-1 self-end mb-[6px]"
                  style={{
                    borderBottom: `1px dotted ${RULE}`,
                    minWidth: "20px",
                  }}
                />
                <span className="tabular-nums text-[15px] font-semibold" style={{ color: INK }}>
                  {s.percentage.toFixed(0)}%
                </span>
              </li>
            ))}
          </ul>
        </Row>

        <Row label="Tijdlijn">
          <TafelScrubber focusIso={focusIso} onSelect={select} />
        </Row>

        <Row label="Tijd">
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => select(nowHourIso())}
              className="px-4 py-2 text-[12px] uppercase tracking-[0.14em] transition-colors cursor-pointer"
              style={{
                background: isNow ? INK : "transparent",
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
                  className="px-4 py-2 text-[12px] uppercase tracking-[0.14em] transition-colors cursor-pointer"
                  style={{
                    background: active ? INK : "transparent",
                    color: active ? BG : INK,
                    border: `1px solid ${active ? INK : RULE}`,
                  }}
                >
                  {j.label}
                </button>
              );
            })}
          </div>
        </Row>

        <div style={{ borderTop: `1px solid ${RULE}` }} />
      </div>
    </main>
  );
}
