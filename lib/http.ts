import { NextResponse } from "next/server";
import { HOUR_MS } from "./ned";

type CacheEntry<T> = { data: T; expiresAt: number };

const MAX_CACHE_SIZE = 100;
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
  if (cache.size >= MAX_CACHE_SIZE && !cache.has(key)) {
    const oldest = cache.keys().next().value!;
    cache.delete(oldest);
  }
  cache.set(key, { data, expiresAt: Date.now() + ttlMs });
}

export type Freshness = { maxAgeSeconds: number; ttlMs: number };

export function freshnessFor(at: Date): Freshness {
  const now = Date.now();
  if (at.getTime() < now - HOUR_MS) return { maxAgeSeconds: 3600, ttlMs: HOUR_MS };
  if (at.getTime() > now) return { maxAgeSeconds: 900, ttlMs: 5 * 60 * 1000 };
  return { maxAgeSeconds: 300, ttlMs: 5 * 60 * 1000 };
}

export function cacheControl(maxAgeSeconds: number): string {
  return maxAgeSeconds > 0 ? `public, max-age=${maxAgeSeconds}` : "no-store";
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export function withCors(headers: Record<string, string> = {}): Record<string, string> {
  return { ...CORS_HEADERS, ...headers };
}

export function optionsResponse(): Response {
  return new Response(null, { status: 204, headers: withCors() });
}

export function jsonResponse(body: unknown, maxAgeSeconds: number): NextResponse {
  return NextResponse.json(body, { headers: withCors({ "Cache-Control": cacheControl(maxAgeSeconds) }) });
}

export function errorResponse(status: number, message: string): NextResponse {
  return NextResponse.json({ error: message }, { status, headers: withCors({ "Cache-Control": "no-store" }) });
}

export function failure(error: unknown): NextResponse {
  return errorResponse(500, error instanceof Error ? error.message : "fout");
}
