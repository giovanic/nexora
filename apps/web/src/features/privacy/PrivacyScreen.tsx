import { useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { ErrorMessage } from "../../shared/ui";
import { ConsentsSection } from "./ConsentsSection";
import { downloadJson } from "./download";
import { PasswordAction } from "./PasswordAction";

type Props = {
  api: Api;
  onSignedOut: () => void;
  download?: (filename: string, content: string) => void;
};

export function PrivacyScreen({ api, onSignedOut, download = downloadJson }: Props) {
  async function exportData(password: string) {
    const result = await api.exportAccount(password);
    if (!result.ok) return result;
    // The content goes straight to the file. It is never kept in state, the DOM or any log.
    download(`meus-dados-${new Date().toISOString().slice(0, 10)}.json`, JSON.stringify(result.data, null, 2));
    return null;
  }

  async function deleteAccount(password: string) {
    const result = await api.deleteAccount(password);
    if (!result.ok) return result;
    onSignedOut();
    return null;
  }

  const [signOutError, setSignOutError] = useState<string | null>(null);
  const [signingOut, setSigningOut] = useState(false);

  // The cookie is HttpOnly: only the server can end the session. If it did not answer, the
  // session is still alive, so the page must not pretend otherwise. A 401 means it is gone.
  async function signOut() {
    setSigningOut(true);
    setSignOutError(null);
    const result = await api.signOut();
    setSigningOut(false);
    if (result.ok || result.status === 401) return onSignedOut();
    setSignOutError(errorMessage(result, "Não foi possível sair. Tente de novo."));
  }

  return (
    <main>
      <h1>Privacidade</h1>
      <p>
        <button type="button" disabled={signingOut} onClick={() => void signOut()}>
          {signOutError ? "Tentar sair de novo" : "Sair"}
        </button>
      </p>
      {signOutError && <ErrorMessage>{signOutError}</ErrorMessage>}
      <ConsentsSection api={api} />
      <PasswordAction
        id="export"
        title="Exportar meus dados"
        description="Baixe um arquivo JSON com os dados da sua conta. Digite a senha para confirmar."
        passwordLabel="Senha para exportar"
        submitLabel="Exportar meus dados"
        busyLabel="Preparando…"
        run={exportData}
        success="Arquivo baixado."
      />
      <PasswordAction
        id="delete"
        title="Excluir minha conta"
        description="Encerra todas as sessões e apaga os seus dados em até 24 horas. Não dá para desfazer. Digite a senha para confirmar."
        passwordLabel="Senha para excluir"
        submitLabel="Excluir minha conta"
        busyLabel="Excluindo…"
        run={deleteAccount}
        wrongPassword="Senha incorreta. Nada foi excluído."
      />
    </main>
  );
}
