"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { apiUrl } from "./api";
import type { Facts } from "./insights";
import type { MixResult } from "./ned";

export type Snapshot = {
  mix: MixResult;
  facts: Facts;
};

export type DashboardInitial = {
  at: string;
  mix: MixResult;
  facts: Facts;
  story: string;
};

export type DashboardState = {
  focusIso: string;
  select: (iso: string) => void;
  snapshot: Snapshot | null;
  story: string | null;
  mixLoading: boolean;
  storyLoading: boolean;
  refreshTrigger: number;
};

export function useDashboardState(initial: DashboardInitial | null): DashboardState {
  const [focusIso, setFocusIso] = useState(() => {
    if (initial?.at) return initial.at;
    const d = new Date();
    d.setUTCMinutes(0, 0, 0);
    return d.toISOString();
  });
  const [snapshot, setSnapshot] = useState<Snapshot | null>(
    initial ? { mix: initial.mix, facts: initial.facts } : null,
  );
  const [story, setStory] = useState<string | null>(initial?.story || null);
  const [mixLoading, setMixLoading] = useState(!initial);
  const [storyLoading, setStoryLoading] = useState(!initial);

  const snapshotCacheRef = useRef(
    new Map<string, Snapshot>(
      initial ? [[initial.at, { mix: initial.mix, facts: initial.facts }]] : [],
    ),
  );
  const storyCacheRef = useRef(
    new Map<string, string>(initial?.story ? [[initial.at, initial.story]] : []),
  );
  const mixAbortRef = useRef<AbortController | null>(null);
  const storyAbortRef = useRef<AbortController | null>(null);
  const currentRequestRef = useRef<string>(focusIso);

  const select = useCallback((iso: string) => {
    setFocusIso(iso);
  }, []);

  const refreshTriggerRef = useRef(0);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  useEffect(() => {
    let hourWhenHidden = "";

    const handleVisibility = () => {
      if (document.visibilityState === "hidden") {
        const d = new Date();
        d.setMinutes(0, 0, 0);
        hourWhenHidden = d.toISOString();
      } else if (hourWhenHidden) {
        const d = new Date();
        d.setMinutes(0, 0, 0);
        if (d.toISOString() !== hourWhenHidden) {
          snapshotCacheRef.current.clear();
          storyCacheRef.current.clear();
          refreshTriggerRef.current += 1;
          setRefreshTrigger(refreshTriggerRef.current);
        }
        hourWhenHidden = "";
      }
    };

    document.addEventListener("visibilitychange", handleVisibility);
    return () => document.removeEventListener("visibilitychange", handleVisibility);
  }, []);

  useEffect(() => {
    currentRequestRef.current = focusIso;

    const cachedSnap = snapshotCacheRef.current.get(focusIso);
    const cachedStory = storyCacheRef.current.get(focusIso);

    if (cachedSnap) {
      setSnapshot(cachedSnap);
      setMixLoading(false);
    } else {
      setMixLoading(true);
      mixAbortRef.current?.abort();
      const ctrl = new AbortController();
      mixAbortRef.current = ctrl;
      fetch(apiUrl(`/api/mix?at=${encodeURIComponent(focusIso)}`), { signal: ctrl.signal })
        .then((r) => r.json())
        .then((data: { mix: MixResult; facts: Facts; error?: string }) => {
          if (currentRequestRef.current !== focusIso) return;
          if (data.error || !data.mix) return;
          const snap: Snapshot = { mix: data.mix, facts: data.facts };
          snapshotCacheRef.current.set(focusIso, snap);
          setSnapshot(snap);
          setMixLoading(false);
        })
        .catch((err) => {
          if (err.name !== "AbortError") setMixLoading(false);
        });
    }

    if (cachedStory) {
      setStory(cachedStory);
      setStoryLoading(false);
    } else {
      setStory("");
      setStoryLoading(true);
      storyAbortRef.current?.abort();
      const ctrl = new AbortController();
      storyAbortRef.current = ctrl;

      (async () => {
        try {
          const res = await fetch(apiUrl(`/api/story?at=${encodeURIComponent(focusIso)}`), {
            signal: ctrl.signal,
          });
          if (!res.body) {
            setStoryLoading(false);
            return;
          }
          const reader = res.body.getReader();
          const decoder = new TextDecoder();
          let acc = "";
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            const chunk = decoder.decode(value, { stream: true });
            acc += chunk;
            if (currentRequestRef.current !== focusIso) return;
            setStory(acc);
          }
          if (currentRequestRef.current !== focusIso) return;
          if (acc.trim()) storyCacheRef.current.set(focusIso, acc.trim());
          setStoryLoading(false);
        } catch (err) {
          if ((err as Error).name !== "AbortError") setStoryLoading(false);
        }
      })();
    }

    return () => {
      mixAbortRef.current?.abort();
      storyAbortRef.current?.abort();
    };
  }, [focusIso, refreshTrigger]);

  return { focusIso, select, snapshot, story, mixLoading, storyLoading, refreshTrigger };
}
