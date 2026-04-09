import type { Facts } from "@/lib/insights";
import { ShimmerLines } from "./Spinner";

export function Insights({
  story,
  facts,
  storyLoading,
}: {
  story: string | null;
  facts: Facts | null;
  storyLoading: boolean;
}) {
  const top3 = facts?.sources.filter((s) => s.percentage >= 1).slice(0, 3) ?? [];

  return (
    <section className="w-full px-1">
      <div className="min-h-[88px]">
        {story && story.length > 0 ? (
          <p className="text-[19px] sm:text-xl text-neutral-100 leading-[1.45] font-light text-pretty">
            {story}
            {storyLoading && <span className="inline-block w-1.5 h-[1.1em] ml-1 -mb-0.5 bg-white/70 align-middle animate-pulse" />}
          </p>
        ) : storyLoading ? (
          <ShimmerLines lines={3} />
        ) : null}
      </div>
      {top3.length > 0 && (
        <>
        <div className="mt-5 flex flex-wrap gap-2">
          {top3.map((s) => {
            const ratio = s.ratio;
            const ratioBadge =
              ratio != null
                ? ratio >= 1
                  ? `${ratio.toFixed(1)}× normaal`
                  : `${Math.round(ratio * 100)}% van normaal`
                : null;
            return (
              <div
                key={s.typeId}
                className="inline-flex items-center gap-2 rounded-full bg-neutral-900/80 backdrop-blur px-3.5 py-1.5 text-[13px] cursor-pointer"
              >
                <span
                  className="w-1.5 h-1.5 rounded-full"
                  style={{ background: s.category === "groen" ? "#65C46A" : "#9CA3AF" }}
                />
                <span className="text-neutral-200 font-medium">{s.label}</span>
                <span className="text-white tabular-nums font-semibold">
                  {s.percentage.toFixed(0)}%
                </span>
                {ratioBadge && <span className="text-neutral-500 tabular-nums">{ratioBadge}</span>}
              </div>
            );
          })}
        </div>
        <p className="mt-3 text-[11px] text-neutral-500 leading-relaxed">
          &ldquo;Normaal&rdquo; is het gemiddelde voor ditzelfde uur van de dag over de afgelopen 30 dagen. 1.5× normaal = anderhalf keer zoveel als gebruikelijk, 50% van normaal = de helft.
        </p>
        </>
      )}
    </section>
  );
}
