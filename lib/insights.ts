import {
  DATA_START_DAY,
  getBaseline,
  getYear,
  shiftDay,
  SOURCE,
  SOURCES,
  toAmsterdamDay,
  type Category,
  type DayPoint,
  type MixResult,
} from "./ned";

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
  topSource?: { label: string; percentage: number };
  sources: SourceFact[];
  notable: string[];
};

export type DayFacts = {
  day: string;
  isToday: boolean;
  greenPct: number;
  totalKWh: number;
  sources: SourceFact[];
  notable: string[];
};

const SUNRISE_BY_MONTH = [8, 8, 7, 7, 6, 5, 5, 6, 7, 8, 8, 8];
const SUNSET_BY_MONTH = [17, 18, 19, 20, 21, 22, 22, 21, 20, 19, 17, 17];
const COMPARABLE_SOURCES = [SOURCE.windOpLand, SOURCE.zon, SOURCE.windOpZee, SOURCE.aardgas, SOURCE.steenkool];

const amsterdamParts = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/Amsterdam",
  month: "numeric",
  hour: "numeric",
  hourCycle: "h23",
});

function isDaylightInNL(at: Date): boolean {
  const parts = amsterdamParts.formatToParts(at);
  const month = Number(parts.find((p) => p.type === "month")?.value) - 1;
  const localHour = Number(parts.find((p) => p.type === "hour")?.value);
  return localHour >= SUNRISE_BY_MONTH[month] && localHour < SUNSET_BY_MONTH[month];
}

function sourceFact(typeId: number, volumeKWh: number, totalKWh: number, baselineKWh: number | undefined): SourceFact {
  const meta = SOURCES.find((s) => s.typeId === typeId)!;
  return {
    typeId,
    label: meta.label,
    category: meta.category,
    percentage: totalKWh > 0 ? (volumeKWh / totalKWh) * 100 : 0,
    volumeKWh,
    baselineKWh,
    ratio: baselineKWh && baselineKWh > 0 ? volumeKWh / baselineKWh : undefined,
  };
}

function find(sources: SourceFact[], typeId: number): SourceFact | undefined {
  return sources.find((s) => s.typeId === typeId);
}

function windRatio(sources: SourceFact[]): number | undefined {
  const ratios = [SOURCE.windOpLand, SOURCE.windOpZee]
    .map((typeId) => find(sources, typeId)?.ratio)
    .filter((r): r is number => r != null);
  if (ratios.length === 0) return undefined;
  return ratios.reduce((a, b) => a + b, 0) / ratios.length;
}

export function prefetchBaselines(hourOfDay: number): Promise<unknown[]> {
  return Promise.all(COMPARABLE_SOURCES.map((typeId) => getBaseline(typeId, hourOfDay)));
}

export async function computeFacts(mix: MixResult): Promise<Facts> {
  const focusDate = new Date(mix.focusTime);
  const baselines = new Map(
    await Promise.all(
      COMPARABLE_SOURCES.map(async (typeId) => [typeId, await getBaseline(typeId, focusDate.getUTCHours())] as const),
    ),
  );

  const sources = mix.sources.map((s) =>
    sourceFact(s.typeId, s.volumeKWh, mix.totalKWh, baselines.get(s.typeId as (typeof COMPARABLE_SOURCES)[number])),
  );
  const isDaytime = isDaylightInNL(focusDate);
  const notable: string[] = [];

  const wind = windRatio(sources);
  if (wind != null) {
    if (wind > 1.5) notable.push(`Het waait flink: wind levert ${wind.toFixed(1)}× het normale niveau voor dit uur.`);
    else if (wind < 0.5) notable.push(`Weinig wind: ongeveer ${Math.round(wind * 100)}% van normaal voor dit uur.`);
    else notable.push("Wind is rond normaal niveau voor dit uur.");
  }

  const sun = find(sources, SOURCE.zon);
  if (!isDaytime) {
    notable.push("Het is donker, dus er is geen zonne-energie.");
  } else if (sun?.ratio != null) {
    if (sun.ratio > 1.2) notable.push("Zonnig: zonne-energie ligt boven het normale niveau.");
    else if (sun.ratio < 0.4) notable.push("Bewolkt: weinig zonne-energie voor dit uur.");
  } else if (sun && sun.percentage > 5) {
    notable.push(`Zon levert ${sun.percentage.toFixed(0)}% van de mix.`);
  }

  const gas = find(sources, SOURCE.aardgas);
  if (gas && gas.percentage > 40) notable.push(`Aardgas vult het gat met ${gas.percentage.toFixed(0)}% van de mix.`);
  const coal = find(sources, SOURCE.steenkool);
  if (coal && coal.percentage > 15) notable.push(`Steenkool draait fors mee (${coal.percentage.toFixed(0)}%).`);

  return {
    focusTime: mix.focusTime,
    greenPct: mix.greenPct,
    totalKWh: mix.totalKWh,
    isDaytime,
    topSource: sources[0] ? { label: sources[0].label, percentage: sources[0].percentage } : undefined,
    sources,
    notable,
  };
}

async function daysAround(day: string): Promise<DayPoint[]> {
  const year = Number(day.slice(0, 4));
  const needsPreviousYear =
    shiftDay(day, -30).slice(0, 4) !== day.slice(0, 4) && `${year - 1}-12-31` >= DATA_START_DAY;
  const years = await Promise.all(needsPreviousYear ? [getYear(year - 1), getYear(year)] : [getYear(year)]);
  return years.flat();
}

export async function computeDayFacts(day: string): Promise<DayFacts | undefined> {
  const points = await daysAround(day);
  const target = points.find((p) => p.date === day);
  if (!target) return undefined;

  const windowStart = shiftDay(day, -30);
  const history = points.filter((p) => p.date >= windowStart && p.date < day);
  const isToday = day === toAmsterdamDay(new Date());

  const sources = SOURCES.map((s, i) => {
    const baseline = history.length > 0 ? history.reduce((sum, p) => sum + p.volumes[i], 0) / history.length : undefined;
    return sourceFact(s.typeId, target.volumes[i], target.totalKWh, baseline);
  })
    .filter((s) => s.volumeKWh > 0)
    .sort((a, b) => b.volumeKWh - a.volumeKWh);

  const notable: string[] = [];
  const wind = windRatio(sources);
  if (wind != null) {
    if (wind > 1.5) notable.push(`Veel wind: ${wind.toFixed(1)}× het gemiddelde van de dertig dagen ervoor.`);
    else if (wind < 0.5) notable.push(`Weinig wind: ongeveer ${Math.round(wind * 100)}% van het gemiddelde van de dertig dagen ervoor.`);
  }
  const sun = find(sources, SOURCE.zon);
  if (sun?.ratio != null) {
    if (sun.ratio > 1.3) notable.push("Zonniger dan de dertig dagen ervoor.");
    else if (sun.ratio < 0.6) notable.push("Minder zon dan de dertig dagen ervoor.");
  }
  const gas = find(sources, SOURCE.aardgas);
  if (gas && gas.percentage > 40) {
    notable.push(`Aardgas ${isToday ? "levert" : "leverde"} ${gas.percentage.toFixed(0)}% van de stroom.`);
  }
  const coal = find(sources, SOURCE.steenkool);
  if (coal && coal.percentage > 15) {
    notable.push(`Steenkool ${isToday ? "draait" : "draaide"} fors mee (${coal.percentage.toFixed(0)}%).`);
  }

  return { day, isToday, greenPct: target.greenPct, totalKWh: target.totalKWh, sources, notable };
}
