"use client";

type Jump = { label: string; offsetDays: number; hour: number };

const JUMPS: Jump[] = [
  { label: "Gisteren",   offsetDays: -1, hour: 12 },
  { label: "Vannacht",   offsetDays: 0,  hour: 3 },
  { label: "Ochtend",    offsetDays: 0,  hour: 9 },
  { label: "Middag",     offsetDays: 0,  hour: 14 },
  { label: "Avond",      offsetDays: 0,  hour: 20 },
  { label: "Morgen",     offsetDays: 1,  hour: 12 },
  { label: "Overmorgen", offsetDays: 2,  hour: 12 },
];

function amsterdamTodayAt(hour: number, offsetDays: number): Date {
  const now = new Date();
  const amsHour = parseInt(
    now.toLocaleString("en-US", { hour: "2-digit", hour12: false, timeZone: "Europe/Amsterdam" }),
    10,
  );
  const t = new Date(now);
  t.setUTCHours(t.getUTCHours() + (hour - amsHour) + offsetDays * 24);
  t.setUTCMinutes(0, 0, 0);
  return t;
}

function nowHourIso(): string {
  const t = new Date();
  t.setUTCMinutes(0, 0, 0);
  t.setUTCHours(t.getUTCHours() - 1);
  return t.toISOString();
}

export function QuickJump({
  focusIso,
  onSelect,
}: {
  focusIso: string;
  onSelect: (iso: string) => void;
}) {
  const focusMs = new Date(focusIso).getTime();
  const isNow = Math.abs(focusMs - Date.now()) < 90 * 60 * 1000;

  return (
    <div className="w-full overflow-x-auto scrollbar-hide -mx-4 px-4">
      <div className="flex gap-2 min-w-max">
        <button
          type="button"
          onClick={() => onSelect(nowHourIso())}
          className={`px-4 py-2.5 rounded-full text-[15px] font-medium transition-colors flex-shrink-0 select-none touch-manipulation ${
            isNow
              ? "bg-white text-neutral-950"
              : "bg-neutral-900 text-neutral-200 border border-neutral-800 active:bg-neutral-800"
          }`}
        >
          Nu
        </button>
        {JUMPS.map((j) => (
          <button
            key={j.label}
            type="button"
            onClick={() => onSelect(amsterdamTodayAt(j.hour, j.offsetDays).toISOString())}
            className="px-4 py-2.5 rounded-full text-[15px] bg-neutral-900 text-neutral-200 border border-neutral-800 active:bg-neutral-800 flex-shrink-0 select-none touch-manipulation"
          >
            {j.label}
          </button>
        ))}
      </div>
    </div>
  );
}
