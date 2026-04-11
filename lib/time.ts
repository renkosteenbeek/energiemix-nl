const AMS_TZ = "Europe/Amsterdam";

export function nowHourIso(): string {
  const t = new Date();
  t.setUTCMinutes(0, 0, 0);
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
