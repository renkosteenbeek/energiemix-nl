"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { HourStrip } from "./HourStrip";
import { Insights } from "./Insights";
import { QuickJump } from "./QuickJump";
import { SourcesDetail } from "./SourcesDetail";
import { SustainabilityHero } from "./SustainabilityHero";
import type { Facts } from "@/lib/insights";
import type { MixResult } from "@/lib/ned";

type Snapshot = {
  mix: MixResult;
  facts: Facts;
};

export type DashboardInitial = {
  at: string;
  mix: MixResult;
  facts: Facts;
  story: string;
};

export function Dashboard({ initial }: { initial: DashboardInitial }) {
  const [focusIso, setFocusIso] = useState(initial.at);
  const [snapshot, setSnapshot] = useState<Snapshot>({ mix: initial.mix, facts: initial.facts });
  const [story, setStory] = useState<string | null>(initial.story || null);
  const [mixLoading, setMixLoading] = useState(false);
  const [storyLoading, setStoryLoading] = useState(false);

  const snapshotCacheRef = useRef(new Map<string, Snapshot>([[initial.at, { mix: initial.mix, facts: initial.facts }]]));
  const storyCacheRef = useRef(new Map<string, string>(initial.story ? [[initial.at, initial.story]] : []));
  const mixAbortRef = useRef<AbortController | null>(null);
  const storyAbortRef = useRef<AbortController | null>(null);
  const currentRequestRef = useRef<string>(initial.at);

  const select = useCallback((iso: string) => {
    setFocusIso(iso);
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
      fetch(`/api/mix?at=${encodeURIComponent(focusIso)}`, { signal: ctrl.signal })
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
          const res = await fetch(`/api/story?at=${encodeURIComponent(focusIso)}`, {
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
  }, [focusIso]);

  return (
    <>
      <SustainabilityHero
        greenPct={snapshot.mix.greenPct}
        validfrom={snapshot.mix.focusTime}
        loading={mixLoading}
      />

      <div className="flex flex-col gap-3">
        <HourStrip focusIso={focusIso} onSelect={select} />
        <QuickJump focusIso={focusIso} onSelect={select} />
      </div>

      <Insights story={story} facts={snapshot.facts} storyLoading={storyLoading} />

      <SourcesDetail sources={snapshot.mix.sources} />
    </>
  );
}
