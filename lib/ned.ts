const BASE = "https://api.ned.nl/v1";

export type Category = "groen" | "grijs";

export type SourceMeta = {
  typeId: number;
  label: string;
  category: Category;
  color: string;
};

export const SOURCES: SourceMeta[] = [
  { typeId: 17, label: "Wind op zee",  category: "groen", color: "#1B4F7E" },
  { typeId: 1,  label: "Wind op land", category: "groen", color: "#5896D1" },
  { typeId: 2,  label: "Zon",          category: "groen", color: "#F5B13B" },
  { typeId: 25, label: "Biomassa",     category: "groen", color: "#7C956E" },
  { typeId: 18, label: "Aardgas",      category: "grijs", color: "#E07A4E" },
  { typeId: 19, label: "Steenkool",    category: "grijs", color: "#2B2A28" },
  { typeId: 20, label: "Kernenergie",  category: "grijs", color: "#8E5BA7" },
  { typeId: 21, label: "Afval",        category: "grijs", color: "#9B7E5A" },
  { typeId: 26, label: "Overig",       category: "grijs", color: "#8D95A0" },
];

export const SOURCE_BY_TYPE = new Map(SOURCES.map((s) => [s.typeId, s]));

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

export const NED_MIN_DATE = new Date("2016-01-01T00:00:00Z");
export const NED_MAX_FORECAST_AHEAD_MS = 5 * 24 * 60 * 60 * 1000;

function dateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function pickClassification(at: Date): number {
  const now = Date.now();
  return at.getTime() > now - 60 * 60 * 1000 ? CLASSIFICATION.forecast : CLASSIFICATION.current;
}

async function fetchUtilizations(params: {
  typeId: number;
  classification: number;
  after: string;
  before: string;
  granularity?: number;
}): Promise<Utilization[]> {
  const apiKey = process.env.NED_API_KEY;
  if (!apiKey) throw new Error("NED_API_KEY niet gezet");

  const qs = new URLSearchParams({
    point: "0",
    type: String(params.typeId),
    granularity: String(params.granularity ?? 5),
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

const CRITICAL_FOSSIL_IDS = new Set<number>([18, 19]);

export type MixResult = {
  focusTime: string;
  greenPct: number;
  totalKWh: number;
  sources: SourceSlice[];
  series: TimePoint[];
};

type Bucket = { total: number; green: number; bySource: Map<number, number> };

function mergeIntoBuckets(perType: { source: SourceMeta; data: Utilization[] }[]): Map<string, Bucket> {
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
  const classification = pickClassification(at);
  const after = new Date(at.getTime() - 14 * 60 * 60 * 1000);
  const before = new Date(at.getTime() + 14 * 60 * 60 * 1000);

  const perType = await Promise.all(
    SOURCES.map(async (s) => ({
      source: s,
      data: await fetchUtilizations({
        typeId: s.typeId,
        classification,
        after: dateOnly(after),
        before: dateOnly(new Date(before.getTime() + 24 * 60 * 60 * 1000)),
      }),
    })),
  );

  const buckets = mergeIntoBuckets(perType);
  const fullSeries = bucketsToSeries(buckets);

  const series = fullSeries.filter((p) => {
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

async function fetchBuckets(
  from: Date,
  to: Date,
  classification: number,
): Promise<Map<string, Bucket>> {
  const perType = await Promise.all(
    SOURCES.map(async (s) => ({
      source: s,
      data: await fetchUtilizations({
        typeId: s.typeId,
        classification,
        after: dateOnly(from),
        before: dateOnly(new Date(to.getTime() + 24 * 60 * 60 * 1000)),
      }),
    })),
  );
  const buckets = mergeIntoBuckets(perType);
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
  const from = new Date(centerAt.getTime() - hoursBack * 60 * 60 * 1000);
  const to = new Date(centerAt.getTime() + hoursForward * 60 * 60 * 1000);
  const now = Date.now();
  const OVERLAP_MS = 3 * 60 * 60 * 1000;

  const ranges: { from: Date; to: Date; classification: number }[] = [];

  if (from.getTime() < now) {
    ranges.push({
      from,
      to: new Date(Math.min(to.getTime(), now + OVERLAP_MS)),
      classification: CLASSIFICATION.current,
    });
  }

  if (to.getTime() > now - OVERLAP_MS) {
    ranges.push({
      from: new Date(Math.max(from.getTime(), now - OVERLAP_MS)),
      to,
      classification: CLASSIFICATION.forecast,
    });
  }

  const results = await Promise.all(
    ranges.map((r) => fetchBuckets(r.from, r.to, r.classification)),
  );

  const mergedBuckets = new Map<string, Bucket>();
  for (const buckets of results) {
    for (const [time, bucket] of buckets) {
      if (!mergedBuckets.has(time)) mergedBuckets.set(time, bucket);
    }
  }

  const nowHourStart = new Date(now);
  nowHourStart.setUTCMinutes(0, 0, 0);
  const nowHourStartMs = nowHourStart.getTime();

  const sortedTimes = [...mergedBuckets.keys()].sort();
  const series: TimePoint[] = [];

  for (const time of sortedTimes) {
    const bucket = mergedBuckets.get(time)!;
    if (bucket.total <= 0) continue;
    const tMs = new Date(time).getTime();
    const isForecast = tMs >= nowHourStartMs;
    const isStrictFuture = tMs > nowHourStartMs;

    if (isStrictFuture) {
      const hasCritical = [...CRITICAL_FOSSIL_IDS].every(
        (id) => (bucket.bySource.get(id) ?? 0) > 0,
      );
      if (!hasCritical) break;
    }

    series.push({
      time,
      greenPct: (bucket.green / bucket.total) * 100,
      totalKWh: bucket.total,
      forecast: isForecast,
    });
  }

  return series;
}

export async function getMixSeries(from: Date, to: Date): Promise<TimePoint[]> {
  const classification = pickClassification(new Date((from.getTime() + to.getTime()) / 2));

  const perType = await Promise.all(
    SOURCES.map(async (s) => ({
      source: s,
      data: await fetchUtilizations({
        typeId: s.typeId,
        classification,
        after: dateOnly(from),
        before: dateOnly(new Date(to.getTime() + 24 * 60 * 60 * 1000)),
      }),
    })),
  );

  const buckets = mergeIntoBuckets(perType);
  return bucketsToSeries(buckets).filter((p) => {
    const t = new Date(p.time).getTime();
    return t >= from.getTime() && t <= to.getTime();
  });
}

const baselineCache = new Map<string, Promise<number>>();

export function getBaseline(typeId: number, hourOfDay: number): Promise<number> {
  const key = `${typeId}:${hourOfDay}`;
  const cached = baselineCache.get(key);
  if (cached) return cached;

  const promise = (async () => {
    const before = new Date();
    const after = new Date(before.getTime() - 30 * 24 * 60 * 60 * 1000);
    const data = await fetchUtilizations({
      typeId,
      classification: CLASSIFICATION.current,
      after: dateOnly(after),
      before: dateOnly(before),
    });
    const matching = data.filter((u) => new Date(u.validfrom).getUTCHours() === hourOfDay);
    if (matching.length === 0) return 0;
    const sum = matching.reduce((s, u) => s + u.volume, 0);
    return sum / matching.length;
  })();

  baselineCache.set(key, promise);
  setTimeout(() => baselineCache.delete(key), 6 * 60 * 60 * 1000).unref?.();
  return promise;
}

export function latestAvailableHour(): Date {
  const now = new Date();
  now.setMinutes(0, 0, 0);
  return now;
}

export function clampAt(at: Date): Date {
  const now = Date.now();
  const min = NED_MIN_DATE.getTime();
  const max = now + NED_MAX_FORECAST_AHEAD_MS;
  return new Date(Math.min(Math.max(at.getTime(), min), max));
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
