import { firstDataYear, getYear, SOURCES, toAmsterdamDay } from "@/lib/ned";
import { errorResponse, failure, jsonResponse, optionsResponse } from "@/lib/http";

export function OPTIONS() {
  return optionsResponse();
}

export async function GET(request: Request) {
  const year = Number(new URL(request.url).searchParams.get("year"));
  const currentYear = Number(toAmsterdamDay(new Date()).slice(0, 4));
  if (!Number.isInteger(year) || year < firstDataYear() || year > currentYear) {
    return errorResponse(400, "ongeldig jaar");
  }

  try {
    const days = await getYear(year);
    const sources = SOURCES.map(({ typeId, label, category }) => ({ typeId, label, category }));
    return jsonResponse({ year, sources, days }, year < currentYear ? 86400 : 1800);
  } catch (error) {
    return failure(error);
  }
}
