import { useCallback, useState } from "react";
import type { Api, Motivation, Profile } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { MAX_MOTIVATIONS, MOTIVATIONS } from "../../shared/options";
import { ConsentNotice } from "./ConsentNotice";
import { useResource } from "../../shared/useResource";
import { Body, Button, Choice, ErrorText, ErrorView, Field, InfoText, LoadingView, Subtitle } from "../../shared/ui";

type Props = { api: Api; onOpenConsent: () => void };

export function ProfileSection({ api, onOpenConsent }: Props) {
  const load = useCallback(() => api.getProfile(), [api]);
  const { state, reload } = useResource(load);

  return (
    <>
      <Subtitle>Perfil</Subtitle>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && state.error.code === "consent_required" && <ConsentNotice onOpenConsent={onOpenConsent} />}
      {state.status === "error" && state.error.code !== "consent_required" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && <ProfileForm api={api} profile={state.data} />}
    </>
  );
}

function ProfileForm({ api, profile }: { api: Api; profile: Profile }) {
  const [name, setName] = useState(profile.display_name ?? "");
  const [motivations, setMotivations] = useState<Motivation[]>(profile.motivations);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  function toggle(value: Motivation) {
    setSaved(false);
    setMotivations((current) =>
      current.includes(value) ? current.filter((item) => item !== value) : current.length < MAX_MOTIVATIONS ? [...current, value] : current,
    );
  }

  async function save() {
    setError(null);
    setSaved(false);
    setBusy(true);
    const result = await api.updateProfile({ display_name: name.trim() === "" ? null : name.trim(), motivations });
    setBusy(false);

    if (result.ok) return setSaved(true);
    setError(errorMessage(result));
  }

  return (
    <>
      <Field
        label="Nome de exibição"
        value={name}
        onChangeText={(value) => {
          setSaved(false);
          setName(value);
        }}
        maxLength={60}
        autoCapitalize="words"
        returnKeyType="done"
      />
      <Body>{`Fuso horário: ${profile.time_zone}`}</Body>
      <Body>O que te trouxe aqui</Body>
      {MOTIVATIONS.map(({ value, label }) => (
        <Choice key={value} label={label} selected={motivations.includes(value)} onPress={() => toggle(value)} />
      ))}
      <ErrorText>{error}</ErrorText>
      <InfoText>{saved ? "Perfil salvo." : null}</InfoText>
      <Button label="Salvar perfil" busy={busy} onPress={save} />
    </>
  );
}
