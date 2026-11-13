import { useCallback, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { useResource } from "../../shared/useResource";
import { Body, Button, EmptyView, ErrorText, ErrorView, LoadingView, Subtitle } from "../../shared/ui";

const UNNAMED = "Aparelho sem nome";

export function SessionsSection({ api }: { api: Api }) {
  const load = useCallback(() => api.listSessions(), [api]);
  const { state, reload } = useResource(load);
  const [error, setError] = useState<string | null>(null);

  async function revoke(id: string) {
    setError(null);
    const result = await api.revokeSession(id);
    if (result.ok) return reload(false);
    setError(errorMessage(result));
  }

  return (
    <>
      <Subtitle>Sessões</Subtitle>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && state.data.sessions.length === 0 && <EmptyView>Nenhuma sessão ativa.</EmptyView>}
      {state.status === "ready" &&
        state.data.sessions.map((entry) => {
          const label = entry.device_label ?? UNNAMED;
          return (
            <SessionRow key={entry.id} label={label} current={entry.current} onRevoke={() => revoke(entry.id)} />
          );
        })}
      <ErrorText>{error}</ErrorText>
    </>
  );
}

function SessionRow({ label, current, onRevoke }: { label: string; current: boolean; onRevoke: () => void }) {
  return (
    <>
      <Body>{label}</Body>
      {current ? <Body>Este aparelho</Body> : <Button label={`Encerrar sessão: ${label}`} variant="secondary" onPress={onRevoke} />}
    </>
  );
}
