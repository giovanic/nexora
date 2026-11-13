import { useState } from "react";
import type { Api, Sport, SportLevel } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { LEVELS, SPORTS } from "../../shared/options";
import { Body, Button, Choice, ErrorText, Screen, Title } from "../../shared/ui";

type Props = { api: Api; onNext: () => void; onConsentRequired: () => void };

// Step 4, optional. Skipping sends nothing.
export function SportsStep({ api, onNext, onConsentRequired }: Props) {
  const [chosen, setChosen] = useState<Partial<Record<Sport, SportLevel>>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function toggle(sport: Sport) {
    setChosen((current) => {
      const next = { ...current };
      if (next[sport]) delete next[sport];
      else next[sport] = "beginner";
      return next;
    });
  }

  async function save() {
    const entries = SPORTS.filter(({ value }) => chosen[value]).map(({ value }) => [value, chosen[value]!] as const);
    if (entries.length === 0) return onNext();

    setError(null);
    setBusy(true);
    for (const [sport, level] of entries) {
      const result = await api.setSportProfile(sport, level);
      if (!result.ok) {
        setBusy(false);
        if (result.code === "consent_required") return onConsentRequired();
        return setError(errorMessage(result));
      }
    }
    setBusy(false);
    onNext();
  }

  return (
    <Screen>
      <Title>Seus esportes</Title>
      <Body>Escolha os que você pratica e o seu nível em cada um. Você pode mudar isso depois.</Body>
      {SPORTS.map(({ value, label }) => (
        <SportRow key={value} label={label} level={chosen[value]} onToggle={() => toggle(value)} onLevel={(level) => setChosen((c) => ({ ...c, [value]: level }))} />
      ))}
      <ErrorText>{error}</ErrorText>
      <Button label="Continuar" busy={busy} onPress={save} />
      <Button label="Pular" variant="secondary" disabled={busy} onPress={onNext} />
    </Screen>
  );
}

function SportRow({ label, level, onToggle, onLevel }: { label: string; level?: SportLevel; onToggle: () => void; onLevel: (level: SportLevel) => void }) {
  return (
    <>
      <Choice label={label} selected={Boolean(level)} onPress={onToggle} />
      {level &&
        LEVELS.map((option) => (
          <Choice key={option.value} kind="radio" label={`${label}: ${option.label}`} selected={level === option.value} onPress={() => onLevel(option.value)} />
        ))}
    </>
  );
}
