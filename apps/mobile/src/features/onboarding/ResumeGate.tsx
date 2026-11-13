import { useCallback, useEffect } from "react";
import type { Api } from "../../shared/api";
import { useResource } from "../../shared/useResource";
import { ErrorView, LoadingView, Screen } from "../../shared/ui";

export const CONSENT_ROUTE = "/onboarding/consent";
export const HOME_ROUTE = "/home";

type Props = { api: Api; onRoute: (path: string) => void };

// Decides where a signed-in person lands. The backend owns the consent state;
// the app only reads it. Without health_data granted, the first-run restarts at the consent step.
export function ResumeGate({ api, onRoute }: Props) {
  const load = useCallback(() => api.listConsents(), [api]);
  const { state, reload } = useResource(load);

  useEffect(() => {
    if (state.status !== "ready") return;
    const health = state.data.consents.find((consent) => consent.purpose === "health_data");
    onRoute(health?.state === "granted" ? HOME_ROUTE : CONSENT_ROUTE);
  }, [state, onRoute]);

  return (
    <Screen>
      {state.status === "error" ? <ErrorView error={state.error} onRetry={reload} /> : <LoadingView />}
    </Screen>
  );
}
