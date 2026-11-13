import { Fragment, useCallback, useState } from "react";
import type { Api, Consent, ConsentPurpose, ConsentText } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { CONSENT_LABELS } from "../../shared/options";
import { useResource } from "../../shared/useResource";
import { Body, Button, ErrorText, ErrorView, InfoText, LoadingView, Subtitle } from "../../shared/ui";

const STATE_LABELS: Record<Consent["state"], string> = {
  granted: "Concedido",
  pending: "Ainda não respondido",
  revoked: "Retirado",
  outdated: "Texto novo: leia e conceda de novo",
};

export const HEALTH_REVOCATION_WARNING =
  "Ao retirar este consentimento, apagamos seus esportes, níveis, motivações e nome de exibição. Sua conta continua, e você volta à tela de consentimento.";
const OTHER_REVOCATION_WARNING = "Ao retirar este consentimento, o app deixa de usar seus dados para esta finalidade.";

type Props = { api: Api; onHealthRevoked: () => void };

export function ConsentsSection({ api, onHealthRevoked }: Props) {
  const load = useCallback(() => api.listConsents(), [api]);
  const { state, reload } = useResource(load);
  const [confirming, setConfirming] = useState<ConsentPurpose | null>(null);
  const [reading, setReading] = useState<ConsentText | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function reset() {
    setConfirming(null);
    setReading(null);
    setError(null);
    setNotice(null);
  }

  async function read(purpose: ConsentPurpose, why?: string) {
    reset();
    setBusy(true);
    const result = await api.getConsentText(purpose);
    setBusy(false);
    if (result.ok) {
      setReading(result.data);
      // The text changed under the person: say why it is shown again.
      if (why) setError(why);
      return;
    }
    setError(errorMessage(result));
  }

  async function grant(text: ConsentText) {
    setError(null);
    setBusy(true);
    const result = await api.grantConsent(text.purpose, text.version);
    setBusy(false);

    if (result.ok) {
      reset();
      return reload(false);
    }
    if (result.code === "outdated_version") return read(text.purpose, errorMessage(result));
    // revocation_pending: shown as a calm message, never retried on its own.
    setError(errorMessage(result));
  }

  async function revoke(purpose: ConsentPurpose) {
    setError(null);
    setBusy(true);
    const result = await api.revokeConsent(purpose);
    setBusy(false);

    if (!result.ok) return setError(errorMessage(result));
    reset();
    if (purpose === "health_data") return onHealthRevoked();
    setNotice("Consentimento retirado.");
    reload(false);
  }

  return (
    <>
      <Subtitle>Consentimentos</Subtitle>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" &&
        state.data.consents.map((consent) => {
          const label = CONSENT_LABELS[consent.purpose];
          return (
            <Fragment key={consent.purpose}>
              <Body>{label}</Body>
              <Body>{STATE_LABELS[consent.state]}</Body>
              {consent.state === "granted" ? (
                <Button label={`Retirar: ${label}`} variant="secondary" disabled={busy} onPress={() => { reset(); setConfirming(consent.purpose); }} />
              ) : (
                <Button label={`Ver texto: ${label}`} variant="secondary" disabled={busy} onPress={() => read(consent.purpose)} />
              )}
              {confirming === consent.purpose && (
                <>
                  <Body>{consent.purpose === "health_data" ? HEALTH_REVOCATION_WARNING : OTHER_REVOCATION_WARNING}</Body>
                  <Button label="Confirmar retirada" variant="danger" busy={busy} onPress={() => revoke(consent.purpose)} />
                  <Button label="Cancelar" variant="secondary" disabled={busy} onPress={reset} />
                </>
              )}
              {reading?.purpose === consent.purpose && (
                <>
                  <Body>{reading.text}</Body>
                  <Button label={`Conceder: ${label}`} busy={busy} onPress={() => grant(reading)} />
                  <Button label="Cancelar" variant="secondary" disabled={busy} onPress={reset} />
                </>
              )}
            </Fragment>
          );
        })}
      <ErrorText>{error}</ErrorText>
      <InfoText>{notice}</InfoText>
    </>
  );
}
