import { useCallback, useEffect, useRef, useState } from "react";
import type { Failure, Result } from "./api";

export type Resource<T> =
  | { status: "loading" }
  | { status: "error"; error: Failure }
  | { status: "ready"; data: T };

// Loads once and again on reload. `load` must be stable (useCallback).
// A 403 consent_required is not an error to show: it sends the person to the consent step.
export function useResource<T>(load: () => Promise<Result<T>>, onConsentRequired?: () => void) {
  const [state, setState] = useState<Resource<T>>({ status: "loading" });
  const [tick, setTick] = useState(0);
  const consentRef = useRef(onConsentRequired);

  useEffect(() => {
    consentRef.current = onConsentRequired;
  });

  useEffect(() => {
    let live = true;
    load().then((result) => {
      if (!live) return;
      if (!result.ok && result.code === "consent_required") consentRef.current?.();
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
