import type { SourceSlice } from "@/lib/ned";

export function SourcesDetail({ sources }: { sources: SourceSlice[] }) {
  if (sources.length === 0) return null;

  const total = sources.reduce((sum, s) => sum + s.volumeKWh, 0);
  if (total === 0) return null;

  return (
    <details className="w-full group rounded-2xl bg-neutral-950 border border-neutral-900">
      <summary className="cursor-pointer list-none flex items-center justify-between px-5 py-4 text-neutral-300 active:bg-neutral-900/60 transition-colors rounded-2xl">
        <span className="text-[15px] font-medium">Alle bronnen</span>
        <span className="text-neutral-500 transition-transform group-open:rotate-90 text-lg leading-none">›</span>
      </summary>
      <div className="px-5 pb-5 pt-1 flex flex-col items-center gap-6">
        <Donut sources={sources} total={total} />
        <ul className="w-full space-y-3 text-[15px]">
          {sources.map((s) => (
            <li key={s.typeId} className="flex items-center gap-3">
              <span
                className="inline-block w-2.5 h-2.5 rounded-full flex-shrink-0"
                style={{ background: s.color }}
              />
              <span className="flex-1 text-neutral-200">{s.label}</span>
              <span className="text-neutral-600 tabular-nums text-[13px]">
                {(s.volumeKWh / 1000).toFixed(0)} MWh
              </span>
              <span className="w-14 text-right text-white tabular-nums font-semibold">
                {s.percentage.toFixed(0)}%
              </span>
            </li>
          ))}
        </ul>
      </div>
    </details>
  );
}

function Donut({ sources, total }: { sources: SourceSlice[]; total: number }) {
  const size = 200;
  const stroke = 28;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  let offset = 0;

  const greenSum = sources.filter((s) => s.category === "groen").reduce((s, x) => s + x.volumeKWh, 0);
  const greenPct = total > 0 ? Math.round((greenSum / total) * 100) : 0;

  return (
    <div className="relative">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <g transform={`translate(${size / 2}, ${size / 2}) rotate(-90)`}>
          <circle r={r} fill="none" stroke="#0a0a0a" strokeWidth={stroke} />
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
        <div className="text-3xl font-semibold tabular-nums text-white">{greenPct}%</div>
        <div className="text-[11px] uppercase tracking-wider text-neutral-500 mt-0.5">groen</div>
      </div>
    </div>
  );
}
