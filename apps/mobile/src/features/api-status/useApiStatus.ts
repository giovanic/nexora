import { useEffect, useState } from "react";
import { fetchReadiness, type FetchFn, type ReadinessResult } from "./fetchReadiness";

export type ApiStatusState = "loading" | ReadinessResult;

export function useApiStatus(baseUrl: string | undefined, fetchFn?: FetchFn): ApiStatusState {
  const [state, setState] = useState<ApiStatusState>("loading");

  useEffect(() => {
    let active = true;

    fetchReadiness(baseUrl, fetchFn).then((result) => {
      if (active) setState(result);
    });

    return () => {
      active = false;
    };
  }, [baseUrl, fetchFn]);

  return state;
}
