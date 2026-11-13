import { useState } from "react";
import type { Api, Motivation } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { MAX_MOTIVATIONS, MOTIVATIONS } from "../../shared/options";
import { Body, Button, Choice, ErrorText, Screen, Title } from "../../shared/ui";

type Props = { api: Api; onNext: () => void; onConsentRequired: () => void };

// Step 3, optional. Skipping sends nothing.
export function MotivationsStep({ api, onNext, onConsentRequired }: Props) {
  const [chosen, setChosen] = useState<Motivation[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function toggle(value: Motivation) {
    setChosen((current) =>
      current.includes(value) ? current.filter((item) => item !== value) : current.length < MAX_MOTIVATIONS ? [...current, value] : current,
    );
  }

  async function save() {
    if (chosen.length === 0) return onNext();

    setError(null);
    setBusy(true);
    const result = await api.updateProfile({ motivations: chosen });
    setBusy(false);

    if (result.ok) return onNext();
    if (result.code === "consent_required") return onConsentRequired();
    setError(errorMessage(result));
  }

  return (
    <Screen>
      <Title>O que te trouxe aqui?</Title>
      <Body>Escolha de uma a quatro opções, se quiser. Você pode mudar isso depois.</Body>
      {MOTIVATIONS.map(({ value, label }) => (
        <Choice key={value} label={label} selected={chosen.includes(value)} onPress={() => toggle(value)} />
      ))}
      <ErrorText>{error}</ErrorText>
      <Button label="Continuar" busy={busy} onPress={save} />
      <Button label="Pular" variant="secondary" disabled={busy} onPress={onNext} />
    </Screen>
  );
}
