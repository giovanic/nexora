import { useCallback, useState } from "react";
import type { Api, Result, Sport, SportLevel, SportProfile } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { LEVELS, SPORTS } from "../../shared/options";
import { useResource } from "../../shared/useResource";
import { Body, Button, Choice, EmptyView, ErrorText, ErrorView, LoadingView, Subtitle } from "../../shared/ui";

type Props = { api: Api; onConsentRequired: () => void };

export function SportsSection({ api, onConsentRequired }: Props) {
  const load = useCallback(() => api.listSportProfiles(), [api]);
  const { state, reload } = useResource(load, onConsentRequired);
  const [error, setError] = useState<string | null>(null);

  async function change(action: Promise<Result<unknown>>) {
    setError(null);
    const result = await action;
    if (result.ok) return reload(false);
    if (result.code === "consent_required") return onConsentRequired();
    setError(errorMessage(result));
  }

  return (
    <>
      <Subtitle>Esportes</Subtitle>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && (
        <>
          {state.data.sport_profiles.length === 0 && <EmptyView>Você ainda não escolheu nenhum esporte.</EmptyView>}
          {SPORTS.map(({ value, label }) => {
            const active: SportProfile | undefined = state.data.sport_profiles.find((entry) => entry.sport === value);
            return (
              <SportRow
                key={value}
                label={label}
                active={active}
                onLevel={(level) => change(api.setSportProfile(value as Sport, level))}
                onStop={() => active && change(api.removeSportProfile(active.id))}
              />
            );
          })}
          <ErrorText>{error}</ErrorText>
        </>
      )}
    </>
  );
}

type RowProps = { label: string; active?: SportProfile; onLevel: (level: SportLevel) => void; onStop: () => void };

function SportRow({ label, active, onLevel, onStop }: RowProps) {
  return (
    <>
      <Body>{label}</Body>
      {LEVELS.map((level) => (
        <Choice key={level.value} kind="radio" label={`${label}: ${level.label}`} selected={active?.level === level.value} onPress={() => onLevel(level.value)} />
      ))}
      {active && <Button label={`Parar: ${label}`} variant="secondary" onPress={onStop} />}
    </>
  );
}
