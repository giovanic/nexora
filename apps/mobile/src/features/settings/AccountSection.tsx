import { useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { Body, Button, ErrorText, Field, LinkButton, Subtitle } from "../../shared/ui";

type Props = {
  api: Api;
  webUrl?: string;
  openUrl: (url: string) => void;
  onSignedOut: () => void;
};

export function AccountSection({ api, webUrl, openUrl, onSignedOut }: Props) {
  const [signingOut, setSigningOut] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function signOut() {
    setSigningOut(true);
    // The session is cleared on this device even if the server cannot be reached.
    await api.signOut();
    onSignedOut();
  }

  async function confirmDelete() {
    if (!password) return setError("Digite a sua senha para excluir a conta.");

    setError(null);
    setBusy(true);
    const result = await api.deleteAccount(password);
    setBusy(false);

    if (result.ok) return onSignedOut();
    if (result.code === "invalid_credentials") return setError("Senha incorreta. Nada foi excluído.");
    setError(errorMessage(result));
  }

  return (
    <>
      <Subtitle>Conta</Subtitle>
      <Body>Para exportar seus dados, use o painel web.</Body>
      {webUrl ? <LinkButton label="Abrir o painel web" onPress={() => openUrl(webUrl)} /> : null}
      <Button label="Sair" variant="secondary" busy={signingOut} onPress={signOut} />
      {!deleting ? (
        <Button label="Excluir conta" variant="secondary" onPress={() => setDeleting(true)} />
      ) : (
        <>
          <Body>
            Excluir a conta encerra todas as sessões e apaga os seus dados em até 24 horas. Não dá para desfazer.
          </Body>
          <Field
            label="Senha para confirmar"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            autoComplete="current-password"
            returnKeyType="done"
            onSubmitEditing={confirmDelete}
          />
          <ErrorText>{error}</ErrorText>
          <Button label="Excluir minha conta" variant="danger" busy={busy} onPress={confirmDelete} />
          <Button
            label="Cancelar"
            variant="secondary"
            disabled={busy}
            onPress={() => {
              setDeleting(false);
              setPassword("");
              setError(null);
            }}
          />
        </>
      )}
    </>
  );
}
