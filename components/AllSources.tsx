"use client";

import { useState } from "react";
import type { SourceSlice } from "@/lib/ned";
import { theme } from "@/lib/theme";

export function AllSources({ sources }: { sources: SourceSlice[] }) {
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
        <span
          className="text-[10px] uppercase tracking-[0.26em]"
          style={{ color: theme.dim }}
        >
          Alle bronnen
        </span>
        <span
          className="text-sm leading-none transition-transform"
          style={{
            color: theme.dim2,
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
                <span className="flex-1" style={{ color: theme.ink }}>
                  {s.label}
                </span>
                <span
                  className="tabular-nums text-[13px]"
                  style={{ color: theme.dim2 }}
                >
                  {(s.volumeKWh / 1000).toFixed(0)} MWh
                </span>
                <span
                  className="w-14 text-right tabular-nums font-semibold"
                  style={{ color: theme.ink }}
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

function Donut({ sources, total }: { sources: SourceSlice[]; total: number }) {
  const size = 200;
  const stroke = 28;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;

  const greenSum = sources
    .filter((s) => s.category === "groen")
    .reduce((s, x) => s + x.volumeKWh, 0);
  const greenPct = total > 0 ? Math.round((greenSum / total) * 100) : 0;

  const segments = sources.reduce<
    { typeId: number; color: string; dash: string; offset: number }[]
  >((acc, s) => {
    const prev = acc[acc.length - 1];
    const prevEnd = prev ? prev.offset + parseFloat(prev.dash.split(" ")[0]) : 0;
    const len = (s.volumeKWh / total) * c;
    acc.push({
      typeId: s.typeId,
      color: s.color,
      dash: `${len} ${c - len}`,
      offset: prevEnd,
    });
    return acc;
  }, []);

  return (
    <div className="relative">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <g transform={`translate(${size / 2}, ${size / 2}) rotate(-90)`}>
          <circle r={r} fill="none" stroke={theme.rule2} strokeWidth={stroke} />
          {segments.map((seg) => (
            <circle
              key={seg.typeId}
              r={r}
              fill="none"
              stroke={seg.color}
              strokeWidth={stroke}
              strokeDasharray={seg.dash}
              strokeDashoffset={-seg.offset}
              strokeLinecap="butt"
            />
          ))}
        </g>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <div
          className="text-3xl font-semibold tabular-nums"
          style={{ color: theme.ink }}
        >
          {greenPct}%
        </div>
        <div
          className="text-[11px] uppercase tracking-[0.18em] mt-0.5"
          style={{ color: theme.dim }}
        >
          groen
        </div>
      </div>
    </div>
  );
}
