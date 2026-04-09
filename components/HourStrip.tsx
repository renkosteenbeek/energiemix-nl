"use client";

import { useEffect, useLayoutEffect, useMemo, useRef } from "react";

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
  const s = d.toLocaleString("en-US", {
    hour: "2-digit",
    hour12: false,
    timeZone: "Europe/Amsterdam",
  });
  return parseInt(s, 10) % 24;
}

const useIsoLayoutEffect = typeof window !== "undefined" ? useLayoutEffect : useEffect;

export function HourStrip({
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

  const handleCellTap = (iso: string) => (e: React.MouseEvent) => {
    e.preventDefault();
    if (iso === focusIso) return;
    onSelect(iso);
  };

  return (
    <div className="relative w-full">
      <div
        className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-10 rounded-2xl"
        style={{
          width: CELL_WIDTH + 4,
          height: 76,
          background: "rgba(255,255,255,0.06)",
          border: "1px solid rgba(255,255,255,0.18)",
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
                onClick={handleCellTap(iso)}
                className="flex-shrink-0 flex flex-col items-center justify-end pb-3 relative select-none touch-manipulation"
                style={{ width: CELL_WIDTH, scrollSnapAlign: "center" }}
              >
                {day && (
                  <div className="absolute top-0 left-0 right-0 text-center text-[10px] uppercase tracking-wider leading-tight">
                    <div className="text-neutral-400">{day.weekday}</div>
                    <div className="text-neutral-600">{day.date}</div>
                  </div>
                )}
                <div
                  className={`text-[15px] tabular-nums transition-colors ${
                    isFocus
                      ? "text-white font-semibold"
                      : cell.isNow
                        ? "text-neutral-200 font-medium"
                        : "text-neutral-500"
                  }`}
                >
                  {hour}
                </div>
                <div
                  className={`mt-1.5 rounded-full transition-all ${
                    isFocus
                      ? "h-2 w-2 bg-white"
                      : cell.isNow
                        ? "h-1.5 w-1.5 bg-neutral-300"
                        : "h-1 w-1 bg-neutral-700"
                  }`}
                />
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
