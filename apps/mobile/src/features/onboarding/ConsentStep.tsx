import { useCallback, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { useResource } from "../../shared/useResource";
import { Body, Button, ErrorText, ErrorView, LinkButton, LoadingView, Screen, Subtitle, Title } from "../../shared/ui";

type Props = { api: Api; onGranted: () => void; onSignOut: () => void; onOpenSettings: () => void };

// Step 2. The text always comes from the server, so the version sent is the one shown.
export function ConsentStep({ api, onGranted, onSignOut, onOpenSettings }: Props) {
  const load = useCallback(() => api.getConsentText("health_data"), [api]);
  const { state, reload } = useResource(load);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function grant(version: number) {
    setError(null);
    setBusy(true);
    const result = await api.grantConsent("health_data", version);
    setBusy(false);

    if (result.ok) return onGranted();
    if (result.code === "outdated_version") reload();
    setError(errorMessage(result));
  }

  return (
    <Screen>
      <Title>Seus dados</Title>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && (
        <>
          <Subtitle>Antes de continuar, leia com calma</Subtitle>
          <Body>{state.data.text}</Body>
          <ErrorText>{error}</ErrorText>
          <Button label="Concordo e continuar" busy={busy} onPress={() => grant(state.data.version)} />
        </>
      )}
      <LinkButton label="Configurações, para excluir a conta ou ver outras opções" onPress={onOpenSettings} />
      <LinkButton label="Sair da conta" onPress={onSignOut} />
    </Screen>
  );
}
