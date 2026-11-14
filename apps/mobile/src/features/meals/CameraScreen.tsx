import { useCallback, useMemo, useRef, useState } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { useResource } from "../../shared/useResource";
import { Body, Button, ErrorText, ErrorView, LinkButton, LoadingView, Screen, Title } from "../../shared/ui";
import { PhotoConsentStep } from "./PhotoConsentStep";
import type { PendingPhotos } from "./PendingPhotos";
import { createUploadFlow, type Prepared, type SendResult, type Uploader } from "./UploadFlow";
import type { Picker } from "./devicePicker";
import { mealErrorMessage } from "./mealMessages";

type Props = {
  api: Api;
  picker: Picker;
  photos: PendingPhotos;
  uploader: Uploader;
  newId: () => string;
  onResult: (entryId: string) => void;
  onManual: () => void;
  onHistory: () => void;
  onOpenSettings: () => void;
  openDeviceSettings: () => void;
};

type Status =
  | { kind: "idle" }
  | { kind: "busy" }
  | { kind: "denied" }
  | { kind: "network" }
  | { kind: "message"; text: string };

const UNSUPPORTED = errorMessage({ ok: false, status: 422, code: "unsupported_media_type" });
const COPY_FAILED = "Não foi possível guardar a foto no aparelho. Tente de novo.";

export function CameraScreen({ api, picker, photos, uploader, newId, onResult, onManual, onHistory, onOpenSettings, openDeviceSettings }: Props) {
  const flow = useMemo(() => createUploadFlow({ api, photos, uploader, newId }), [api, photos, uploader, newId]);
  const loadConsents = useCallback(() => api.listConsents(), [api]);
  const consents = useResource(loadConsents);
  const [askConsent, setAskConsent] = useState(false);
  const [justGranted, setJustGranted] = useState(false);
  const [status, setStatus] = useState<Status>({ kind: "idle" });
  // The photo that still has to be sent, kept for retry with the same client_request_id.
  const pending = useRef<Prepared | null>(null);

  async function send(prepared: Prepared) {
    pending.current = prepared;
    setStatus({ kind: "busy" });
    const result: SendResult = await flow.send(prepared);

    if (result.kind === "sent") {
      pending.current = null;
      setStatus({ kind: "idle" });
      return onResult(result.entryId);
    }
    if (result.kind === "network") return setStatus({ kind: "network" });

    const { failure } = result;
    if (failure.code === "consent_operator_mismatch" || failure.code === "consent_required") {
      // The photo stays on the device: it is sent once the person agrees.
      setStatus({ kind: "idle" });
      setJustGranted(false);
      return setAskConsent(true);
    }
    pending.current = null;
    setStatus({ kind: "message", text: mealErrorMessage(failure) });
  }

  async function pick(source: "takePhoto" | "choosePhoto") {
    setStatus({ kind: "busy" });
    const picked = await picker[source]();
    if (picked.kind === "denied") return setStatus({ kind: "denied" });
    if (picked.kind === "canceled") return setStatus({ kind: "idle" });

    const prepared = await flow.prepare(picked.photo);
    if (prepared.kind === "unsupported") return setStatus({ kind: "message", text: UNSUPPORTED });
    if (prepared.kind === "copy_failed") return setStatus({ kind: "message", text: COPY_FAILED });
    await send(prepared.prepared);
  }

  async function consentGranted() {
    setAskConsent(false);
    setJustGranted(true);
    if (pending.current) await send(pending.current);
  }

  const needsConsent =
    askConsent ||
    (!justGranted &&
      consents.state.status === "ready" && consents.state.data.consents.find((item) => item.purpose === "food_photo_ai")?.state !== "granted");


  return (
    <Screen>
      <Title>Registrar refeição</Title>
      {consents.state.status === "loading" && <LoadingView />}
      {consents.state.status === "error" && <ErrorView error={consents.state.error} onRetry={consents.reload} />}
      {consents.state.status === "ready" && needsConsent && <PhotoConsentStep api={api} onGranted={consentGranted} onManual={onManual} />}
      {consents.state.status === "ready" && !needsConsent && (
        <>
          {status.kind === "busy" && <LoadingView label="Enviando a foto…" />}
          {status.kind === "denied" && (
            <>
              <Body>
                Sem acesso à câmera, não dá para tirar a foto. Você pode liberar o acesso nos ajustes do aparelho ou registrar a refeição sem foto.
              </Body>
              <Button label="Abrir os ajustes do aparelho" variant="secondary" onPress={openDeviceSettings} />
            </>
          )}
          {status.kind === "network" && (
            <>
              <ErrorText>Não foi possível enviar a foto. Ela continua guardada no aparelho.</ErrorText>
              <Button label="Tentar enviar de novo" onPress={() => pending.current && send(pending.current)} />
            </>
          )}
          {status.kind === "message" && <ErrorText>{status.text}</ErrorText>}
          {status.kind !== "busy" && (
            <>
              <Button label="Tirar uma foto" onPress={() => pick("takePhoto")} />
              <Button label="Escolher da galeria" variant="secondary" onPress={() => pick("choosePhoto")} />
            </>
          )}
          <LinkButton label="Registrar sem foto" onPress={onManual} />
        </>
      )}
      <LinkButton label="Ver histórico" onPress={onHistory} />
      <LinkButton label="Configurações" onPress={onOpenSettings} />
    </Screen>
  );
}
