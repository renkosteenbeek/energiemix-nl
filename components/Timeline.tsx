"use client";

import { useMemo } from "react";
import { colorForGreenPct, type TimePoint } from "@/lib/ned";
import { theme } from "@/lib/theme";
import { amsterdamHour, compactDateLabel, shortWeekday } from "@/lib/time";
import { useTimeScrubber } from "@/lib/useTimeScrubber";

const HOURS_BACK = 24;
const HOURS_FORWARD = 48;

type Bar = {
  iso: string;
  t: Date;
  greenPct: number | null;
  isMidnightAms: boolean;
  isFuture: boolean;
};

export function Timeline({
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
      arr.push({
        iso: t.toISOString(),
        t,
        greenPct: byHour.get(t.getTime()) ?? null,
        isMidnightAms: amsterdamHour(t) === 0,
        isFuture: i > 0,
      });
    }
    return arr;
  }, [timeline, nowHour]);

  const dayBoundaries = bars
    .map((bar, i) => ({ bar, i }))
    .filter(({ bar }) => bar.isMidnightAms)
    .map(({ bar, i }) => ({
      pct: i / (bars.length - 1),
      label: shortWeekday(bar.t),
    }));

  const previewBar = bars.find((b) => b.iso === previewIso);
  const previewLabel = previewBar ? compactDateLabel(previewBar.iso) : "";
  const previewGreen =
    previewBar?.greenPct != null ? Math.round(previewBar.greenPct) : null;

  return (
    <div className="w-full select-none">
      <div className="flex items-end justify-between mb-4">
        <div>
          <div
            className="text-[10px] uppercase tracking-[0.26em] mb-1"
            style={{ color: theme.dim }}
          >
            Dagritme
          </div>
          <div className="text-[13px] first-letter:uppercase" style={{ color: theme.ink }}>
            {previewLabel}
            {previewGreen != null && (
              <>
                <span style={{ color: theme.dim2 }}> · </span>
                <span
                  className="tabular-nums font-medium"
                  style={{ color: colorForGreenPct(previewGreen) }}
                >
                  {previewGreen}%
                </span>
              </>
            )}
          </div>
        </div>
        <div className="flex gap-1">
          <StepButton direction="back" onClick={() => step(-1)} />
          <StepButton direction="forward" onClick={() => step(1)} />
        </div>
      </div>

      <div className="relative">
        <div
          {...bindings}
          className="relative flex items-end gap-[1.5px] h-[96px] cursor-pointer touch-none"
          style={{ WebkitUserSelect: "none" }}
        >
          {bars.map((bar) => (
            <BarColumn key={bar.iso} bar={bar} />
          ))}
        </div>

        <div
          className="absolute top-0 bottom-0 pointer-events-none"
          style={{
            left: `${nowPct * 100}%`,
            width: 1,
            background: theme.ink,
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
            background: theme.ink,
            transform: "translateX(-1px)",
          }}
        >
          <div
            className="absolute -left-[3px] -top-[3px]"
            style={{
              width: 8,
              height: 8,
              background: theme.ink,
              borderRadius: "1px",
              transform: "rotate(45deg)",
            }}
          />
        </div>
      </div>

      <div
        className="relative mt-2 pt-2 pb-1 h-[22px]"
        style={{ borderTop: `1px solid ${theme.rule2}` }}
      >
        {dayBoundaries.map((d) => (
          <AxisLabel
            key={d.pct}
            leftPct={d.pct}
            text={d.label}
            color={theme.dim2}
          />
        ))}
        <AxisLabel
          leftPct={nowPct}
          text="nu"
          color={theme.ink}
          bold
        />
      </div>
    </div>
  );
}

function BarColumn({ bar }: { bar: Bar }) {
  const hasData = bar.greenPct != null;
  const greenPct = bar.greenPct ?? 0;
  const hMin = 6;
  const hMax = 96;
  const height = hasData ? Math.max(hMin, (greenPct / 100) * hMax) : hMin;
  return (
    <div
      className="flex-1 relative flex items-end pointer-events-none"
      style={{ height: "100%" }}
    >
      <div
        className="w-full transition-[height] duration-300 ease-out"
        style={{
          height: `${height}px`,
          background: hasData ? colorForGreenPct(greenPct) : theme.emptyBar,
          borderRadius: "1px",
          opacity: bar.isFuture ? 0.92 : 1,
        }}
      />
    </div>
  );
}

function AxisLabel({
  leftPct,
  text,
  color,
  bold = false,
}: {
  leftPct: number;
  text: string;
  color: string;
  bold?: boolean;
}) {
  return (
    <div
      className={`absolute top-2 text-[9px] uppercase tracking-[0.14em] ${bold ? "font-medium" : ""}`}
      style={{
        left: `${leftPct * 100}%`,
        transform: "translateX(-50%)",
        color,
      }}
    >
      {text}
    </div>
  );
}

function StepButton({
  direction,
  onClick,
}: {
  direction: "back" | "forward";
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="w-7 h-7 rounded-full flex items-center justify-center text-[12px] cursor-pointer transition-colors"
      style={{ color: theme.ink, border: `1px solid ${theme.rule}` }}
      aria-label={direction === "back" ? "uur terug" : "uur vooruit"}
    >
      {direction === "back" ? "←" : "→"}
    </button>
  );
}
