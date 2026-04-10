const BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

export function apiUrl(path: string): string {
  return `${BASE}${path}`;
}

export const isNativeBuild = BASE.length > 0;
