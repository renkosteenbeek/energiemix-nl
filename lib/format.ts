export function formatGWh(kWh: number): string {
  const gwh = kWh / 1_000_000;
  return gwh >= 10 ? `${Math.round(gwh)} GWh` : `${gwh.toFixed(1)} GWh`;
}
