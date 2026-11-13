import { useCallback, useEffect, useRef, useState } from "react";
import type { Api, Consent, ConsentPurpose, ConsentText } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { ErrorMessage, Panel } from "../../shared/ui";

const LABELS: Record<ConsentPurpose, string> = {
  health_data: "Dados de saúde",
  food_photo_ai: "Fotos de refeição para a IA",
  strava_integration: "Integração com o Strava",
  usage_metrics: "Métricas de uso",
};

const STATES: Record<Consent["state"], string> = {
  granted: "Concedido",
  pending: "Ainda não respondido",
  revoked: "Retirado",
  outdated: "Texto novo: leia e conceda de novo",
};

type Load = { kind: "loading" } | { kind: "error"; message: string } | { kind: "ready"; consents: Consent[] };

export function ConsentsSection({ api }: { api: Api }) {
  const [load, setLoad] = useState<Load>({ kind: "loading" });
  const [reading, setReading] = useState<ConsentText | null>(null);
  const [confirming, setConfirming] = useState<ConsentPurpose | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const result = await api.listConsents();
    setLoad(result.ok ? { kind: "ready", consents: result.data.consents } : { kind: "error", message: errorMessage(result) });
  }, [api]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const triggers = useRef<Partial<Record<ConsentPurpose, HTMLButtonElement | null>>>({});

  // Closing a panel puts focus back on the button that opened it.
  function close(purpose: ConsentPurpose) {
    setReading(null);
    setConfirming(null);
    setTimeout(() => triggers.current[purpose]?.focus(), 0);
  }

  // `why` stays on screen when the text is shown again because it changed under the person.
  async function read(purpose: ConsentPurpose, why?: string) {
    setProblem(null);
    setNotice(null);
    setConfirming(null);
    const result = await api.getConsentText(purpose);
    if (result.ok) {
      setReading(result.data);
      if (why) setProblem(why);
    } else {
      setProblem(errorMessage(result));
    }
  }

  async function grant(text: ConsentText) {
    setBusy(true);
    setProblem(null);
    const result = await api.grantConsent(text.purpose, text.version);
    setBusy(false);
    if (result.ok) {
      setReading(null);
      setNotice(`Consentimento concedido: ${LABELS[text.purpose]}.`);
      await refresh();
    } else if (result.code === "outdated_version") {
      await read(text.purpose, errorMessage(result));
    } else {
      // revocation_pending and the rest: one calm message, no automatic retry.
      setProblem(errorMessage(result));
    }
  }

  async function revoke(purpose: ConsentPurpose) {
    setBusy(true);
    setProblem(null);
    const result = await api.revokeConsent(purpose);
    setBusy(false);
    setConfirming(null);
    if (result.ok) {
      setNotice(`Consentimento retirado: ${LABELS[purpose]}.`);
      await refresh();
    } else {
      setProblem(errorMessage(result));
    }
  }

  return (
    <section aria-labelledby="consents-title">
      <h2 id="consents-title">Consentimentos</h2>
      {load.kind === "loading" && <p role="status">Carregando os consentimentos…</p>}
      {load.kind === "error" && (
        <>
          <p role="alert">{load.message}</p>
          <button type="button" onClick={() => { setLoad({ kind: "loading" }); void refresh(); }}>
            Tentar de novo
          </button>
        </>
      )}
      {load.kind === "ready" && load.consents.length === 0 && <p>Nenhum consentimento para mostrar.</p>}
      {load.kind === "ready" && load.consents.length > 0 && (
        <ul>
          {load.consents.map((consent) => (
            <li key={consent.purpose} aria-label={LABELS[consent.purpose]}>
              <strong>{LABELS[consent.purpose]}</strong> <span>{STATES[consent.state]}</span>{" "}
              {consent.state === "granted" ? (
                <button type="button" ref={(el) => { triggers.current[consent.purpose] = el; }} onClick={() => { setReading(null); setNotice(null); setProblem(null); setConfirming(consent.purpose); }}>
                  Retirar
                </button>
              ) : (
                <button type="button" ref={(el) => { triggers.current[consent.purpose] = el; }} onClick={() => void read(consent.purpose)}>
                  Ler e conceder
                </button>
              )}
              {reading?.purpose === consent.purpose && (
                <Panel key={reading.version} title={`Texto de ${LABELS[reading.purpose]}`}>
                  <pre style={{ whiteSpace: "pre-wrap", font: "inherit" }}>{reading.text}</pre>
                  <button type="button" disabled={busy} onClick={() => void grant(reading)}>
                    Aceitar a versão {reading.version}
                  </button>{" "}
                  <button type="button" onClick={() => close(consent.purpose)}>
                    Agora não
                  </button>
                </Panel>
              )}
              {confirming === consent.purpose && (
                <Panel title={`Retirar o consentimento de ${LABELS[consent.purpose].toLowerCase()}`}>
                  {consent.purpose === "health_data" ? (
                    <p>
                      Ao retirar este consentimento, seus esportes, níveis, motivações e nome de exibição são apagados. A conta continua. Você pode conceder de
                      novo quando quiser.
                    </p>
                  ) : (
                    <p>Você pode conceder de novo quando quiser.</p>
                  )}
                  <button type="button" disabled={busy} onClick={() => void revoke(consent.purpose)}>
                    Confirmar a retirada
                  </button>{" "}
                  <button type="button" onClick={() => close(consent.purpose)}>
                    Manter
                  </button>
                </Panel>
              )}
            </li>
          ))}
        </ul>
      )}
      <div aria-live="polite">{notice}</div>
      {problem && <ErrorMessage>{problem}</ErrorMessage>}
    </section>
  );
}
