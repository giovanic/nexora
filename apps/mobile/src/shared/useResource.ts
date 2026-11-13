import { useCallback, useEffect, useState } from "react";
import type { Failure, Result } from "./api";

export type Resource<T> =
  | { status: "loading" }
  | { status: "error"; error: Failure }
  | { status: "ready"; data: T };

// Loads once and again on reload. `load` must be stable (useCallback).
export function useResource<T>(load: () => Promise<Result<T>>) {
  const [state, setState] = useState<Resource<T>>({ status: "loading" });
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    load().then((result) => {
      if (!live) return;
      setState(result.ok ? { status: "ready", data: result.data } : { status: "error", error: result });
    });
    return () => {
      live = false;
    };
  }, [load, tick]);

  const reload = useCallback((showLoading = true) => {
    if (showLoading) setState({ status: "loading" });
    setTick((value) => value + 1);
  }, []);

  return { state, reload };
}
