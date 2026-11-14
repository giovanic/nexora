import { useCallback, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { useResource } from "../../shared/useResource";
import { Body, Button, ErrorText, ErrorView, LinkButton, LoadingView, Subtitle } from "../../shared/ui";

type Props = { api: Api; onGranted: () => void; onManual: () => void };

// Asked before the first photo. The text always comes from the server, so the version sent is the one shown.
export function PhotoConsentStep({ api, onGranted, onManual }: Props) {
  const load = useCallback(() => api.getConsentText("food_photo_ai"), [api]);
  const { state, reload } = useResource(load);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function grant(version: number) {
    setError(null);
    setBusy(true);
    const result = await api.grantConsent("food_photo_ai", version);
    setBusy(false);

    if (result.ok) return onGranted();
    if (result.code === "outdated_version") reload();
    setError(errorMessage(result));
  }

  return (
    <>
      <Subtitle>Antes da primeira foto</Subtitle>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && (
        <>
          <Body>{state.data.text}</Body>
          <ErrorText>{error}</ErrorText>
          <Button label="Concordo e continuar" busy={busy} onPress={() => grant(state.data.version)} />
        </>
      )}
      <LinkButton label="Registrar sem foto" onPress={onManual} />
    </>
  );
}
