import { useCallback, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { useResource } from "../../shared/useResource";
import { Body, Button, EmptyView, ErrorText, ErrorView, LoadingView, Subtitle } from "../../shared/ui";

const UNNAMED = "Aparelho sem nome";
const KINDS = { mobile: "Aplicativo no celular", web: "Navegador" } as const;

// dd/mm/aaaa in the device time zone, without depending on Intl support.
function formatDate(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "data desconhecida";
  const two = (value: number) => String(value).padStart(2, "0");
  return `${two(date.getDate())}/${two(date.getMonth() + 1)}/${date.getFullYear()}`;
}

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
            <SessionRow key={entry.id} label={label} detail={`${KINDS[entry.client]} · último uso em ${formatDate(entry.last_used_at)}`} current={entry.current} onRevoke={() => revoke(entry.id)} />
          );
        })}
      <ErrorText>{error}</ErrorText>
    </>
  );
}

function SessionRow({ label, detail, current, onRevoke }: { label: string; detail: string; current: boolean; onRevoke: () => void }) {
  return (
    <>
      <Body>{label}</Body>
      <Body>{detail}</Body>
      {current ? <Body>Este aparelho</Body> : <Button label={`Encerrar sessão: ${label}`} variant="secondary" onPress={onRevoke} />}
    </>
  );
}
