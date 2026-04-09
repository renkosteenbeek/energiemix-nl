import { Spinner } from "./Spinner";
import { colorForGreenPct, colorForGreenPctSoft } from "@/lib/ned";

function temporalLabel(validfrom: string): string {
  if (!validfrom) return "";
  const t = new Date(validfrom).getTime();
  const now = Date.now();
  const diffMin = Math.round((t - now) / 60000);
  if (Math.abs(diffMin) < 90) return "nu";
  if (diffMin < 0) {
    const h = Math.round(-diffMin / 60);
    if (h < 36) return `${h}\u00a0uur geleden`;
    const d = Math.round(h / 24);
    return `${d}\u00a0dagen geleden`;
  }
  const h = Math.round(diffMin / 60);
  if (h < 36) return `over ${h}\u00a0uur`;
  const d = Math.round(h / 24);
  return `over ${d}\u00a0dagen`;
}

function dayLabel(validfrom: string): string {
  if (!validfrom) return "";
  return new Date(validfrom).toLocaleString("nl-NL", {
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Amsterdam",
  });
}

export function SustainabilityHero({
  greenPct,
  validfrom,
  loading = false,
}: {
  greenPct: number;
  validfrom: string;
  loading?: boolean;
}) {
  const top = colorForGreenPct(greenPct);
  const bottom = colorForGreenPctSoft(greenPct);
  const rounded = Math.round(greenPct);
  const tlabel = temporalLabel(validfrom);
  const dlabel = dayLabel(validfrom);

  return (
    <section
      className="relative w-full rounded-[32px] overflow-hidden"
      style={{
        background: `radial-gradient(120% 100% at 30% 0%, ${top} 0%, ${bottom} 70%, #000 130%)`,
      }}
    >
      <div className="px-6 pt-7 pb-9 sm:pt-10 sm:pb-12 flex flex-col">
        <div className="flex items-center justify-between gap-3">
          <div className="text-[11px] uppercase tracking-[0.18em] text-white/55 first-letter:uppercase">
            {dlabel}
          </div>
          <div
            className={`text-white/70 transition-opacity duration-200 ${loading ? "opacity-100" : "opacity-0"}`}
          >
            <Spinner size={16} />
          </div>
        </div>
        <div className="mt-1 flex items-baseline">
          <div
            className="font-semibold tabular-nums text-white leading-none tracking-tighter"
            style={{ fontSize: "clamp(7rem, 38vw, 16rem)" }}
          >
            {rounded}
          </div>
          <div className="text-white/80 font-medium ml-1" style={{ fontSize: "clamp(2rem, 8vw, 4rem)" }}>
            %
          </div>
        </div>
        <div className="mt-1 text-2xl sm:text-3xl text-white/90 font-light tracking-tight">
          duurzaam <span className="text-white/55">· {tlabel}</span>
        </div>
      </div>
    </section>
  );
}
