const AMS_TZ = "Europe/Amsterdam";

export type Jump = { label: string; offsetDays: number; hour: number };

export const JUMPS: Jump[] = [
  { label: "Gisteren", offsetDays: -1, hour: 12 },
  { label: "Vannacht", offsetDays: 0, hour: 3 },
  { label: "Ochtend", offsetDays: 0, hour: 9 },
  { label: "Middag", offsetDays: 0, hour: 14 },
  { label: "Avond", offsetDays: 0, hour: 20 },
  { label: "Morgen", offsetDays: 1, hour: 12 },
];

export function amsterdamHour(d: Date): number {
  return parseInt(
    d.toLocaleString("en-US", { hour: "2-digit", hour12: false, timeZone: AMS_TZ }),
    10,
  ) % 24;
}

export function amsterdamAt(hour: number, offsetDays: number): string {
  const now = new Date();
  const t = new Date(now);
  t.setUTCHours(t.getUTCHours() + (hour - amsterdamHour(now)) + offsetDays * 24);
  t.setUTCMinutes(0, 0, 0);
  return t.toISOString();
}

export function nowHourIso(): string {
  const t = new Date();
  t.setUTCMinutes(0, 0, 0);
  t.setUTCHours(t.getUTCHours() - 1);
  return t.toISOString();
}

export function temporalLabel(iso: string): string {
  if (!iso) return "";
  const diffMin = Math.round((new Date(iso).getTime() - Date.now()) / 60000);
  if (Math.abs(diffMin) < 90) return "nu";
  if (diffMin < 0) {
    const h = Math.round(-diffMin / 60);
    if (h < 36) return `${h}\u00a0uur geleden`;
    return `${Math.round(h / 24)}\u00a0dagen geleden`;
  }
  const h = Math.round(diffMin / 60);
  if (h < 36) return `over ${h}\u00a0uur`;
  return `over ${Math.round(h / 24)}\u00a0dagen`;
}

export function longDateLabel(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nl-NL", {
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: AMS_TZ,
  });
}

export function compactDateLabel(iso: string): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nl-NL", {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: AMS_TZ,
  });
}

export function shortWeekday(t: Date): string {
  return t
    .toLocaleDateString("nl-NL", { weekday: "short", timeZone: AMS_TZ })
    .replace(".", "");
}
