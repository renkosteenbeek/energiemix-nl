type CacheEntry<T> = { data: T; expiresAt: number };

const cache = new Map<string, CacheEntry<unknown>>();

export function getCached<T>(key: string): T | undefined {
  const entry = cache.get(key);
  if (!entry) return undefined;
  if (Date.now() > entry.expiresAt) {
    cache.delete(key);
    return undefined;
  }
  return entry.data as T;
}

export function setCache<T>(key: string, data: T, ttlMs: number): void {
  cache.set(key, { data, expiresAt: Date.now() + ttlMs });
}

export function cacheControl(at: Date): string {
  const now = Date.now();
  const atMs = at.getTime();
  const hourAgo = now - 60 * 60 * 1000;

  if (atMs < hourAgo) return "public, max-age=3600";
  if (atMs > now) return "public, max-age=900";
  return "public, max-age=300";
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export function withCors(headers: Record<string, string>): Record<string, string> {
  return { ...CORS_HEADERS, ...headers };
}
