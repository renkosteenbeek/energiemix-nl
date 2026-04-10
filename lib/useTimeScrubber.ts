"use client";

import { Haptics, ImpactStyle } from "@capacitor/haptics";
import { useCallback, useMemo, useRef, useState, type RefObject } from "react";

export type HourCell = {
  t: Date;
  iso: string;
  hoursFromNow: number;
  isNow: boolean;
  amsterdamHour: number;
  isMidnightAms: boolean;
};

export type ScrubberBindings = {
  ref: RefObject<HTMLDivElement | null>;
  onPointerDown: (e: React.PointerEvent) => void;
  onPointerMove: (e: React.PointerEvent) => void;
  onPointerUp: (e: React.PointerEvent) => void;
  onPointerCancel: (e: React.PointerEvent) => void;
};

export type TimeScrubber = {
  cells: HourCell[];
  indicatorPct: number | null;
  nowPct: number | null;
  previewIso: string;
  isDragging: boolean;
  bindings: ScrubberBindings;
  step: (delta: number) => void;
};

export function useTimeScrubber(options: {
  focusIso: string;
  onSelect: (iso: string) => void;
  hoursBack: number;
  hoursForward: number;
  windowOffsetHours?: number;
  maxHoursForward?: number;
}): TimeScrubber {
  const { focusIso, onSelect, hoursBack, hoursForward, windowOffsetHours = 0, maxHoursForward } = options;
  const trackRef = useRef<HTMLDivElement | null>(null);
  const draggingRef = useRef(false);
  const dragIsoRef = useRef<string | null>(null);
  const [dragIso, setDragIso] = useState<string | null>(null);

  const nowHour = useMemo(() => {
    const d = new Date();
    d.setUTCMinutes(0, 0, 0);
    return d;
  }, []);

  const windowStart = -hoursBack + windowOffsetHours;
  const rawWindowEnd = hoursForward + windowOffsetHours;
  const windowEnd = maxHoursForward != null ? Math.min(rawWindowEnd, maxHoursForward) : rawWindowEnd;
  const total = windowEnd - windowStart + 1;

  const cells = useMemo<HourCell[]>(() => {
    const arr: HourCell[] = [];
    for (let i = windowStart; i <= windowEnd; i++) {
      const t = new Date(nowHour.getTime() + i * 3600000);
      const amsH =
        parseInt(
          t.toLocaleString("en-US", {
            hour: "2-digit",
            hour12: false,
            timeZone: "Europe/Amsterdam",
          }),
          10,
        ) % 24;
      arr.push({
        t,
        iso: t.toISOString(),
        hoursFromNow: i,
        isNow: i === 0,
        amsterdamHour: amsH,
        isMidnightAms: amsH === 0,
      });
    }
    return arr;
  }, [nowHour, windowStart, windowEnd]);

  const effectiveIso = dragIso ?? focusIso;

  const effectiveHourMs = useMemo(() => {
    const d = new Date(effectiveIso);
    d.setUTCMinutes(0, 0, 0);
    return d.getTime();
  }, [effectiveIso]);

  const hourOffset = Math.round((effectiveHourMs - nowHour.getTime()) / 3600000);
  const focusInWindow = hourOffset >= windowStart && hourOffset <= windowEnd;
  const indicatorPct =
    focusInWindow && total > 1 ? (hourOffset - windowStart) / (total - 1) : null;
  const nowInWindow = windowStart <= 0 && 0 <= windowEnd;
  const nowPct = nowInWindow && total > 1 ? (0 - windowStart) / (total - 1) : null;

  const pickCellFromX = useCallback(
    (clientX: number): HourCell | null => {
      const el = trackRef.current;
      if (!el) return null;
      const rect = el.getBoundingClientRect();
      if (rect.width === 0) return null;
      const x = Math.max(0, Math.min(rect.width, clientX - rect.left));
      const pct = x / rect.width;
      const idx = Math.round(pct * (total - 1));
      return cells[idx] ?? null;
    },
    [cells, total],
  );

  const setPreview = useCallback((iso: string | null) => {
    dragIsoRef.current = iso;
    setDragIso(iso);
  }, []);

  const onPointerDown = useCallback(
    (e: React.PointerEvent) => {
      e.preventDefault();
      draggingRef.current = true;
      try {
        (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
      } catch {}
      const cell = pickCellFromX(e.clientX);
      if (cell) {
        setPreview(cell.iso);
        Haptics.impact({ style: ImpactStyle.Medium }).catch(() => {});
      }
    },
    [pickCellFromX, setPreview],
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!draggingRef.current) return;
      const cell = pickCellFromX(e.clientX);
      if (cell && cell.iso !== dragIsoRef.current) {
        setPreview(cell.iso);
        Haptics.impact({ style: ImpactStyle.Light }).catch(() => {});
      }
    },
    [pickCellFromX, setPreview],
  );

  const commit = useCallback(
    (e: React.PointerEvent) => {
      if (!draggingRef.current) return;
      draggingRef.current = false;
      try {
        (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
      } catch {}
      const final = dragIsoRef.current;
      setPreview(null);
      if (final && final !== focusIso) onSelect(final);
    },
    [focusIso, onSelect, setPreview],
  );

  const step = useCallback(
    (delta: number) => {
      const base = Math.round((effectiveHourMs - nowHour.getTime()) / 3600000);
      const next = base + delta;
      const iso = new Date(nowHour.getTime() + next * 3600000).toISOString();
      if (iso !== focusIso) onSelect(iso);
    },
    [effectiveHourMs, nowHour, focusIso, onSelect],
  );

  return {
    cells,
    indicatorPct,
    nowPct,
    previewIso: effectiveIso,
    isDragging: dragIso !== null,
    bindings: {
      ref: trackRef,
      onPointerDown,
      onPointerMove,
      onPointerUp: commit,
      onPointerCancel: commit,
    },
    step,
  };
}
