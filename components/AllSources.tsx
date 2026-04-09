"use client";

import { useState } from "react";
import type { SourceSlice } from "@/lib/ned";
import { theme } from "@/lib/theme";

export function AllSources({ sources }: { sources: SourceSlice[] }) {
  const [open, setOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<number | null>(null);

  if (sources.length === 0) return null;
  const total = sources.reduce((sum, s) => sum + s.volumeKWh, 0);
  if (total === 0) return null;

  const toggleSelect = (id: number) => {
    setSelectedId((prev) => (prev === id ? null : id));
  };

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
          <Donut
            sources={sources}
            total={total}
            selectedId={selectedId}
            onSelect={toggleSelect}
          />
          <ul className="w-full space-y-1 text-[15px]">
            {sources.map((s) => {
              const isSelected = selectedId === s.typeId;
              const isDimmed = selectedId != null && !isSelected;
              return (
                <li key={s.typeId}>
                  <button
                    type="button"
                    onClick={() => toggleSelect(s.typeId)}
                    className="w-full flex items-center gap-3 py-2 cursor-pointer transition-opacity"
                    style={{ opacity: isDimmed ? 0.4 : 1 }}
                  >
                    <span
                      className="inline-block w-2.5 h-2.5 rounded-full flex-shrink-0"
                      style={{ background: s.color }}
                    />
                    <span
                      className="flex-1 text-left"
                      style={{
                        color: theme.ink,
                        fontWeight: isSelected ? 600 : 400,
                      }}
                    >
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
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}

function Donut({
  sources,
  total,
  selectedId,
  onSelect,
}: {
  sources: SourceSlice[];
  total: number;
  selectedId: number | null;
  onSelect: (id: number) => void;
}) {
  const size = 200;
  const stroke = 28;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;

  const greenSum = sources
    .filter((s) => s.category === "groen")
    .reduce((s, x) => s + x.volumeKWh, 0);
  const greenPct = total > 0 ? Math.round((greenSum / total) * 100) : 0;

  const segments = sources.reduce<
    {
      typeId: number;
      label: string;
      color: string;
      percentage: number;
      dash: string;
      offset: number;
      length: number;
    }[]
  >((acc, s) => {
    const prev = acc[acc.length - 1];
    const prevEnd = prev ? prev.offset + prev.length : 0;
    const length = (s.volumeKWh / total) * c;
    acc.push({
      typeId: s.typeId,
      label: s.label,
      color: s.color,
      percentage: s.percentage,
      dash: `${length} ${c - length}`,
      offset: prevEnd,
      length,
    });
    return acc;
  }, []);

  const selected = segments.find((seg) => seg.typeId === selectedId) ?? null;

  return (
    <div className="relative">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <g transform={`translate(${size / 2}, ${size / 2}) rotate(-90)`}>
          <circle
            r={r}
            fill="none"
            stroke={theme.rule2}
            strokeWidth={stroke}
            pointerEvents="none"
          />
          {segments.map((seg) => {
            const isSelected = selectedId === seg.typeId;
            const isDimmed = selectedId != null && !isSelected;
            return (
              <circle
                key={seg.typeId}
                r={r}
                fill="none"
                stroke={seg.color}
                strokeWidth={stroke}
                strokeDasharray={seg.dash}
                strokeDashoffset={-seg.offset}
                strokeLinecap="butt"
                onClick={() => onSelect(seg.typeId)}
                style={{
                  cursor: "pointer",
                  opacity: isDimmed ? 0.32 : 1,
                  transition: "opacity 200ms ease",
                  touchAction: "manipulation",
                }}
              />
            );
          })}
        </g>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        {selected ? (
          <>
            <div
              className="text-3xl font-semibold tabular-nums leading-none"
              style={{ color: theme.ink }}
            >
              {Math.round(selected.percentage)}%
            </div>
            <div className="flex items-center gap-1.5 mt-2 max-w-[140px]">
              <span
                className="w-1.5 h-1.5 rounded-full flex-shrink-0"
                style={{ background: selected.color }}
              />
              <span
                className="text-[11px] tracking-[0.04em] truncate"
                style={{ color: theme.ink }}
              >
                {selected.label}
              </span>
            </div>
          </>
        ) : (
          <>
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
          </>
        )}
      </div>
    </div>
  );
}
