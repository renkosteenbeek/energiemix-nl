import { getBaseline, getMixAt, type Category, type MixResult, type SourceSlice } from "./ned";

export type SourceFact = {
  typeId: number;
  label: string;
  category: Category;
  percentage: number;
  volumeKWh: number;
  baselineKWh?: number;
  ratio?: number;
};

export type Facts = {
  focusTime: string;
  greenPct: number;
  totalKWh: number;
  isDaytime: boolean;
  isFuture: boolean;
  topSource?: { label: string; percentage: number };
  sources: SourceFact[];
  notable: string[];
};

const SUNRISE_BY_MONTH = [8, 8, 7, 7, 6, 5, 5, 6, 7, 8, 8, 8];
const SUNSET_BY_MONTH = [17, 18, 19, 20, 21, 22, 22, 21, 20, 19, 17, 17];

function isDaylightInNL(at: Date): boolean {
  const month = at.getUTCMonth();
  const localHour = (at.getUTCHours() + 1) % 24;
  return localHour >= SUNRISE_BY_MONTH[month] && localHour < SUNSET_BY_MONTH[month];
}

const COMPARABLE_SOURCES = [1, 2, 17, 18, 19];

export function prefetchBaselines(hourOfDay: number): Promise<unknown[]> {
  return Promise.all(COMPARABLE_SOURCES.map((typeId) => getBaseline(typeId, hourOfDay)));
}

export async function computeFacts(at: Date, prefetchedMix?: MixResult): Promise<Facts> {
  const mix = prefetchedMix ?? (await getMixAt(at));
  const focusDate = new Date(mix.focusTime || at.toISOString());

  const baselines = await Promise.all(
    COMPARABLE_SOURCES.map(async (typeId) => ({
      typeId,
      baseline: await getBaseline(typeId, focusDate.getUTCHours()),
    })),
  );
  const baselineMap = new Map(baselines.map((b) => [b.typeId, b.baseline]));

  const sources: SourceFact[] = mix.sources.map((s: SourceSlice) => {
    const baseline = baselineMap.get(s.typeId);
    const ratio = baseline && baseline > 0 ? s.volumeKWh / baseline : undefined;
    return {
      typeId: s.typeId,
      label: s.label,
      category: s.category,
      percentage: s.percentage,
      volumeKWh: s.volumeKWh,
      baselineKWh: baseline,
      ratio,
    };
  });

  const isDaytime = isDaylightInNL(focusDate);
  const isFuture = focusDate.getTime() > Date.now();

  const notable: string[] = [];

  const wind1 = sources.find((s) => s.typeId === 1);
  const wind17 = sources.find((s) => s.typeId === 17);
  const sun = sources.find((s) => s.typeId === 2);
  const gas = sources.find((s) => s.typeId === 18);
  const coal = sources.find((s) => s.typeId === 19);

  const totalWindRatio = (() => {
    const a = wind1?.ratio;
    const b = wind17?.ratio;
    if (a == null && b == null) return undefined;
    return ((a ?? 0) + (b ?? 0)) / [a, b].filter((x) => x != null).length;
  })();

  if (totalWindRatio != null) {
    if (totalWindRatio > 1.5) notable.push(`Het waait flink: wind levert ${totalWindRatio.toFixed(1)}× het normale niveau voor dit uur.`);
    else if (totalWindRatio < 0.5) notable.push(`Weinig wind: ongeveer ${Math.round(totalWindRatio * 100)}% van normaal voor dit uur.`);
    else notable.push(`Wind is rond normaal niveau voor dit uur.`);
  }

  if (!isDaytime) {
    notable.push("Het is donker, dus er is geen zonne-energie.");
  } else if (sun?.ratio != null) {
    if (sun.ratio > 1.2) notable.push("Zonnig: zonne-energie ligt boven het normale niveau.");
    else if (sun.ratio < 0.4) notable.push("Bewolkt: weinig zonne-energie voor dit uur.");
  } else if (sun && sun.percentage > 5) {
    notable.push(`Zon levert ${sun.percentage.toFixed(0)}% van de mix.`);
  }

  if (gas && gas.percentage > 40) notable.push(`Aardgas vult het gat met ${gas.percentage.toFixed(0)}% van de mix.`);
  if (coal && coal.percentage > 15) notable.push(`Steenkool draait fors mee (${coal.percentage.toFixed(0)}%).`);

  const topSource = sources[0]
    ? { label: sources[0].label, percentage: sources[0].percentage }
    : undefined;

  return {
    focusTime: mix.focusTime,
    greenPct: mix.greenPct,
    totalKWh: mix.totalKWh,
    isDaytime,
    isFuture,
    topSource,
    sources,
    notable,
  };
}
