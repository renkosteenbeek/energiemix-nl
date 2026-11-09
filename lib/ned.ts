const BASE = "https://api.ned.nl/v1";

export const HOUR_MS = 60 * 60 * 1000;
export const DAY_MS = 24 * HOUR_MS;

export const DATA_START_DAY = "2021-01-01";
export const DATA_START = new Date(`${DATA_START_DAY}T00:00:00+01:00`);
export const NED_MAX_FORECAST_AHEAD_MS = 5 * DAY_MS;

export type Category = "groen" | "grijs";

export const SOURCE = {
  windOpZee: 17,
  windOpLand: 1,
  zon: 2,
  biomassa: 25,
  aardgas: 18,
  steenkool: 19,
  kernenergie: 20,
  afval: 21,
  overig: 26,
} as const;

export type SourceMeta = {
  typeId: number;
  label: string;
  category: Category;
  color: string;
};

export const SOURCES: SourceMeta[] = [
  { typeId: SOURCE.windOpZee, label: "Wind op zee", category: "groen", color: "#1B4F7E" },
  { typeId: SOURCE.windOpLand, label: "Wind op land", category: "groen", color: "#5896D1" },
  { typeId: SOURCE.zon, label: "Zon", category: "groen", color: "#F5B13B" },
  { typeId: SOURCE.biomassa, label: "Biomassa", category: "groen", color: "#7C956E" },
  { typeId: SOURCE.aardgas, label: "Aardgas", category: "grijs", color: "#E07A4E" },
  { typeId: SOURCE.steenkool, label: "Steenkool", category: "grijs", color: "var(--color-coal)" },
  { typeId: SOURCE.kernenergie, label: "Kernenergie", category: "grijs", color: "#8E5BA7" },
  { typeId: SOURCE.afval, label: "Afval", category: "grijs", color: "#9B7E5A" },
  { typeId: SOURCE.overig, label: "Overig", category: "grijs", color: "#8D95A0" },
];

type Utilization = {
  validfrom: string;
  validto: string;
  volume: number;
  capacity: number;
  percentage: number;
};

type HydraResponse<T> = {
  "hydra:member": T[];
  "hydra:totalItems": number;
  "hydra:view"?: {
    "hydra:next"?: string;
  };
};

const CLASSIFICATION = { forecast: 1, current: 2 } as const;
const GRANULARITY = { hour: 5, day: 6 } as const;

function dateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function pickClassification(at: Date): number {
  return at.getTime() > Date.now() - HOUR_MS ? CLASSIFICATION.forecast : CLASSIFICATION.current;
}

async function fetchUtilizations(params: {
  typeId: number;
  classification: number;
  after: string;
  before: string;
  granularity: number;
}): Promise<Utilization[]> {
  const apiKey = process.env.NED_API_KEY;
  if (!apiKey) throw new Error("NED_API_KEY niet gezet");

  const qs = new URLSearchParams({
    point: "0",
    type: String(params.typeId),
    granularity: String(params.granularity),
    granularitytimezone: "1",
    classification: String(params.classification),
    activity: "1",
    "validfrom[strictly_after]": params.after,
    "validfrom[strictly_before]": params.before,
    "order[validfrom]": "asc",
    itemsPerPage: "200",
  });

  const collected: Utilization[] = [];
  let nextUrl: string | null = `${BASE}/utilizations?${qs.toString()}`;
  let safety = 50;

  while (nextUrl && safety-- > 0) {
    const res: Response = await fetch(nextUrl, {
      headers: {
        "X-AUTH-TOKEN": apiKey,
        Accept: "application/ld+json",
      },
      next: { revalidate: 300 },
    });

    if (!res.ok) {
      throw new Error(`NED ${res.status}: ${await res.text()}`);
    }

    const json = (await res.json()) as HydraResponse<Utilization>;
    collected.push(...(json["hydra:member"] ?? []));

    const nextPath = json["hydra:view"]?.["hydra:next"];
    nextUrl = nextPath ? new URL(nextPath, "https://api.ned.nl").toString() : null;
  }

  return collected;
}

type SourceData = { source: SourceMeta; data: Utilization[] };

function fetchAllSources(params: {
  classification: number;
  after: string;
  before: string;
  granularity: number;
}): Promise<SourceData[]> {
  return Promise.all(
    SOURCES.map(async (source) => ({ source, data: await fetchUtilizations({ typeId: source.typeId, ...params }) })),
  );
}

function fetchHourlyAround(from: Date, to: Date, classification: number): Promise<SourceData[]> {
  return fetchAllSources({
    classification,
    after: dateOnly(from),
    before: dateOnly(new Date(to.getTime() + DAY_MS)),
    granularity: GRANULARITY.hour,
  });
}

export type SourceSlice = {
  typeId: number;
  label: string;
  category: Category;
  color: string;
  volumeKWh: number;
  percentage: number;
};

export type TimePoint = {
  time: string;
  greenPct: number;
  totalKWh: number;
  forecast?: boolean;
};

export type MixResult = {
  focusTime: string;
  greenPct: number;
  totalKWh: number;
  sources: SourceSlice[];
  series: TimePoint[];
};

type Bucket = { total: number; green: number; bySource: Map<number, number> };

function mergeIntoBuckets(perType: SourceData[]): Map<string, Bucket> {
  const buckets = new Map<string, Bucket>();
  for (const { source, data } of perType) {
    for (const u of data) {
      const bucket = buckets.get(u.validfrom) ?? {
        total: 0,
        green: 0,
        bySource: new Map<number, number>(),
      };
      bucket.total += u.volume;
      if (source.category === "groen") bucket.green += u.volume;
      bucket.bySource.set(source.typeId, (bucket.bySource.get(source.typeId) ?? 0) + u.volume);
      buckets.set(u.validfrom, bucket);
    }
  }
  return buckets;
}

function bucketsToSeries(buckets: Map<string, Bucket>): TimePoint[] {
  return [...buckets.keys()]
    .sort()
    .map((t) => {
      const b = buckets.get(t)!;
      return {
        time: t,
        greenPct: b.total > 0 ? (b.green / b.total) * 100 : 0,
        totalKWh: b.total,
      };
    })
    .filter((p) => p.totalKWh > 0);
}

function pickFocus(series: TimePoint[], at: Date): TimePoint | undefined {
  if (series.length === 0) return undefined;
  const target = at.getTime();
  let best = series[0];
  let bestDiff = Math.abs(new Date(best.time).getTime() - target);
  for (const p of series) {
    const diff = Math.abs(new Date(p.time).getTime() - target);
    if (diff < bestDiff) {
      best = p;
      bestDiff = diff;
    }
  }
  return best;
}

export async function getMixAt(at: Date): Promise<MixResult> {
  const after = new Date(at.getTime() - 14 * HOUR_MS);
  const before = new Date(at.getTime() + 14 * HOUR_MS);
  const buckets = mergeIntoBuckets(await fetchHourlyAround(after, before, pickClassification(at)));

  const series = bucketsToSeries(buckets).filter((p) => {
    const t = new Date(p.time).getTime();
    return t >= after.getTime() && t <= before.getTime();
  });

  const focus = pickFocus(series, at);
  const focusBucket = focus ? buckets.get(focus.time) : undefined;

  const sources: SourceSlice[] = SOURCES.map((s) => {
    const vol = focusBucket?.bySource.get(s.typeId) ?? 0;
    return {
      typeId: s.typeId,
      label: s.label,
      category: s.category,
      color: s.color,
      volumeKWh: vol,
      percentage: focusBucket && focusBucket.total > 0 ? (vol / focusBucket.total) * 100 : 0,
    };
  })
    .filter((s) => s.volumeKWh > 0)
    .sort((a, b) => b.volumeKWh - a.volumeKWh);

  return {
    focusTime: focus?.time ?? at.toISOString(),
    greenPct: focus?.greenPct ?? 0,
    totalKWh: focusBucket?.total ?? 0,
    sources,
    series,
  };
}

async function fetchBuckets(from: Date, to: Date, classification: number): Promise<Map<string, Bucket>> {
  const buckets = mergeIntoBuckets(await fetchHourlyAround(from, to, classification));
  for (const time of [...buckets.keys()]) {
    const t = new Date(time).getTime();
    if (t < from.getTime() || t > to.getTime()) buckets.delete(time);
  }
  return buckets;
}

export async function getGreenTimeline(
  centerAt: Date,
  hoursBack: number,
  hoursForward: number,
): Promise<TimePoint[]> {
  const from = new Date(centerAt.getTime() - hoursBack * HOUR_MS);
  const to = new Date(centerAt.getTime() + hoursForward * HOUR_MS);
  const now = Date.now();
  const overlap = 3 * HOUR_MS;

  const ranges: { from: Date; to: Date; classification: number }[] = [];

  if (from.getTime() < now) {
    ranges.push({
      from,
      to: new Date(Math.min(to.getTime(), now + overlap)),
      classification: CLASSIFICATION.current,
    });
  }

  if (to.getTime() > now - overlap) {
    ranges.push({
      from: new Date(Math.max(from.getTime(), now - overlap)),
      to,
      classification: CLASSIFICATION.forecast,
    });
  }

  const results = await Promise.all(ranges.map((r) => fetchBuckets(r.from, r.to, r.classification)));

  const mergedBuckets = new Map<string, Bucket>();
  for (const buckets of results) {
    for (const [time, bucket] of buckets) {
      const existing = mergedBuckets.get(time);
      if (!existing || bucket.total > existing.total) {
        mergedBuckets.set(time, bucket);
      }
    }
  }

  const nowHourStartMs = Math.floor(now / HOUR_MS) * HOUR_MS;
  const series: TimePoint[] = [];
  for (const time of [...mergedBuckets.keys()].sort()) {
    const bucket = mergedBuckets.get(time)!;
    if (bucket.total <= 0) continue;
    series.push({
      time,
      greenPct: (bucket.green / bucket.total) * 100,
      totalKWh: bucket.total,
      forecast: new Date(time).getTime() > nowHourStartMs,
    });
  }

  return series;
}

const baselineCache = new Map<string, Promise<number>>();

export function getBaseline(typeId: number, hourOfDay: number): Promise<number> {
  const key = `${typeId}:${hourOfDay}`;
  const cached = baselineCache.get(key);
  if (cached) return cached;

  const promise = (async () => {
    const before = new Date();
    const after = new Date(before.getTime() - 30 * DAY_MS);
    const data = await fetchUtilizations({
      typeId,
      classification: CLASSIFICATION.current,
      after: dateOnly(after),
      before: dateOnly(before),
      granularity: GRANULARITY.hour,
    });
    const matching = data.filter((u) => new Date(u.validfrom).getUTCHours() === hourOfDay);
    if (matching.length === 0) return 0;
    return matching.reduce((s, u) => s + u.volume, 0) / matching.length;
  })();

  baselineCache.set(key, promise);
  promise.catch(() => {
    if (baselineCache.get(key) === promise) baselineCache.delete(key);
  });
  setTimeout(() => {
    if (baselineCache.get(key) === promise) baselineCache.delete(key);
  }, 6 * HOUR_MS).unref?.();
  return promise;
}

export type DayPoint = {
  date: string;
  totalKWh: number;
  greenPct: number;
  volumes: number[];
};

const amsterdamDayFormat = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Europe/Amsterdam",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

export function toAmsterdamDay(date: Date): string {
  return amsterdamDayFormat.format(date);
}

export function shiftDay(day: string, days: number): string {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export async function getDailyRange(fromDay: string, toDay: string): Promise<DayPoint[]> {
  const perType = await fetchAllSources({
    classification: CLASSIFICATION.current,
    after: shiftDay(fromDay, -2),
    before: shiftDay(toDay, 2),
    granularity: GRANULARITY.day,
  });

  const byDay = new Map<string, number[]>();
  perType.forEach(({ data }, sourceIndex) => {
    for (const u of data) {
      const day = toAmsterdamDay(new Date(u.validfrom));
      if (day < fromDay || day > toDay) continue;
      const volumes = byDay.get(day) ?? SOURCES.map(() => 0);
      volumes[sourceIndex] += u.volume;
      byDay.set(day, volumes);
    }
  });

  return [...byDay.keys()].sort().flatMap((date) => {
    const volumes = byDay.get(date)!;
    const total = volumes.reduce((sum, v) => sum + v, 0);
    if (total <= 0) return [];
    const green = volumes.reduce((sum, v, i) => (SOURCES[i].category === "groen" ? sum + v : sum), 0);
    return [{ date, totalKWh: total, greenPct: (green / total) * 100, volumes }];
  });
}

type YearCacheEntry = { expiresAt: number; promise: Promise<DayPoint[]> };
const yearCacheKey = Symbol.for("energiemix.yearCache");
const globalWithCache = globalThis as typeof globalThis & { [yearCacheKey]?: Map<number, YearCacheEntry> };
const yearCache = (globalWithCache[yearCacheKey] ??= new Map<number, YearCacheEntry>());

export function firstDataYear(): number {
  return Number(DATA_START_DAY.slice(0, 4));
}

export function getYear(year: number): Promise<DayPoint[]> {
  const now = Date.now();
  const cached = yearCache.get(year);
  if (cached && cached.expiresAt > now) return cached.promise;

  const today = toAmsterdamDay(new Date(now));
  const isCurrent = today.startsWith(`${year}-`);
  const isSettling = isCurrent || shiftDay(today, -3).startsWith(`${year}-`);
  const promise = getDailyRange(`${year}-01-01`, isCurrent ? today : `${year}-12-31`);
  yearCache.set(year, { expiresAt: now + (isSettling ? 30 * 60 * 1000 : DAY_MS), promise });
  promise.catch(() => {
    if (yearCache.get(year)?.promise === promise) yearCache.delete(year);
  });
  return promise;
}

export function latestAvailableHour(): Date {
  const now = new Date();
  now.setMinutes(0, 0, 0);
  return now;
}

export function clampAt(at: Date): Date {
  const max = Date.now() + NED_MAX_FORECAST_AHEAD_MS;
  return new Date(Math.min(Math.max(at.getTime(), DATA_START.getTime()), max));
}

export function colorForGreenPct(pct: number): string {
  if (pct < 30) return "#B91C1C";
  if (pct < 50) return "#D97706";
  if (pct < 70) return "#65C46A";
  return "#0F5132";
}

export function colorForGreenPctSoft(pct: number): string {
  if (pct < 30) return "#7F1D1D";
  if (pct < 50) return "#92400E";
  if (pct < 70) return "#166534";
  return "#0B3D2A";
}
