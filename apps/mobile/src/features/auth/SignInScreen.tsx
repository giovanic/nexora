import { useRef, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { Button, type InputRef, ErrorText, Field, LinkButton, Screen, Title } from "../../shared/ui";

type Props = {
  api: Api;
  onSignedIn: () => void;
  onGoToSignUp: () => void;
  onGoToForgotPassword: () => void;
};

export function SignInScreen({ api, onSignedIn, onGoToSignUp, onGoToForgotPassword }: Props) {
  const passwordRef = useRef<InputRef>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (busy) return;
    if (!email.trim() || !password) return setError("Digite o e-mail e a senha.");

    setError(null);
    setBusy(true);
    const result = await api.signIn(email.trim(), password);
    setBusy(false);

    if (result.ok) return onSignedIn();
    setError(errorMessage(result));
  }

  return (
    <Screen>
      <Title>Entrar</Title>
      <Field
        label="E-mail"
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoComplete="email"
        textContentType="emailAddress"
        returnKeyType="next"
        onSubmitEditing={() => passwordRef.current?.focus()}
      />
      <Field
        label="Senha"
        inputRef={passwordRef}
        value={password}
        onChangeText={setPassword}
        secureTextEntry
        autoComplete="current-password"
        textContentType="password"
        returnKeyType="go"
        onSubmitEditing={submit}
      />
      <ErrorText>{error}</ErrorText>
      <Button label="Entrar" busy={busy} onPress={submit} />
      <LinkButton label="Esqueci minha senha" onPress={onGoToForgotPassword} />
      <LinkButton label="Criar conta" onPress={onGoToSignUp} />
    </Screen>
  );
}
