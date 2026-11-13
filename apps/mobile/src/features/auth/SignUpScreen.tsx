import { useRef, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { deviceTimeZone } from "../../shared/timeZone";
import { Button, type InputRef, Choice, ErrorText, Field, LinkButton, Screen, Title } from "../../shared/ui";

type Props = {
  api: Api;
  getTimeZone?: () => string | null;
  onSignedUp: () => void;
  onGoToSignIn: () => void;
};

export function SignUpScreen({ api, getTimeZone = deviceTimeZone, onSignedUp, onGoToSignIn }: Props) {
  const passwordRef = useRef<InputRef>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [adult, setAdult] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (busy) return;
    if (!email.trim() || !password) return setError("Digite o e-mail e a senha.");
    if (!adult) return setError("Para criar a conta, confirme que você tem 18 anos ou mais.");

    const timeZone = getTimeZone();
    if (!timeZone) {
      return setError("Não conseguimos identificar o fuso horário do aparelho. Confira as configurações de data e hora e tente de novo.");
    }

    setError(null);
    setBusy(true);
    const result = await api.signUp({ email: email.trim(), password, timeZone });
    setBusy(false);

    if (result.ok) return onSignedUp();
    setError(errorMessage(result, "Confira os dados. A senha precisa ter de 12 a 72 caracteres."));
  }

  return (
    <Screen>
      <Title>Criar conta</Title>
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
        autoComplete="new-password"
        textContentType="newPassword"
        returnKeyType="go"
        onSubmitEditing={submit}
      />
      <Choice label="Tenho 18 anos ou mais" selected={adult} onPress={() => setAdult((value) => !value)} />
      <ErrorText>{error}</ErrorText>
      <Button label="Criar conta" busy={busy} onPress={submit} />
      <LinkButton label="Já tenho conta" onPress={onGoToSignIn} />
    </Screen>
  );
}
