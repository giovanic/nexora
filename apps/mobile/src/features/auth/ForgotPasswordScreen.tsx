import { useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { Body, Button, ErrorText, Field, InfoText, LinkButton, Screen, Title } from "../../shared/ui";

type Props = { api: Api; onBack: () => void };

export function ForgotPasswordScreen({ api, onBack }: Props) {
  const [email, setEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (busy) return;
    if (!email.trim()) return setError("Digite o seu e-mail.");

    setError(null);
    setBusy(true);
    const result = await api.requestPasswordReset(email.trim());
    setBusy(false);

    if (result.ok) return setSent(true);
    setError(errorMessage(result));
  }

  return (
    <Screen>
      <Title>Recuperar senha</Title>
      <Body>Digite o e-mail da sua conta. Se houver uma conta, enviamos um link para criar uma nova senha no painel web.</Body>
      <Field
        label="E-mail"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoComplete="email"
        textContentType="emailAddress"
        returnKeyType="go"
        onSubmitEditing={submit}
      />
      <ErrorText>{error}</ErrorText>
      <InfoText>
        {sent
          ? "Se houver uma conta com este e-mail, enviamos um link para redefinir a senha. Abra o link, troque a senha e volte aqui para entrar."
          : null}
      </InfoText>
      <Button label="Enviar link" busy={busy} onPress={submit} />
      <LinkButton label="Voltar para entrar" onPress={onBack} />
    </Screen>
  );
}
