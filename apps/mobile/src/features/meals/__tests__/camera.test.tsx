import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { consentList, errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { ENTRY_ID, analysisAccepted, fakeFs, fakePicker, fakeUploader, jpeg, uploadGrant } from "../../../shared/testing/mealFakes";
import { CameraScreen } from "../CameraScreen";
import { createPendingPhotos } from "../../../shared/PendingPhotos";
import type { PickResult } from "../devicePicker";

const consentText = jsonResponse(200, { purpose: "food_photo_ai", version: 1, text: "Sua foto é enviada ao provedor para identificar os alimentos." });

function setup(options: { pick?: PickResult; routes?: Record<string, unknown>; consents?: Record<string, string>; uploads?: Parameters<typeof fakeUploader>[0]; files?: ReturnType<typeof fakeFs> } = {}) {
  const ctx = makeApi({
    "GET /api/v1/consents": consentList(options.consents ?? { food_photo_ai: "granted" }),
    "GET /api/v1/consents/food_photo_ai/text": consentText,
    "POST /api/v1/food_entries/uploads": uploadGrant(),
    "POST /api/v1/food_entries/11111111-1111-4111-8111-111111111111/analysis": analysisAccepted(),
    ...options.routes,
  } as never);
  const files = options.files ?? fakeFs();
  files.seed("file:///cache/photo.jpg");
  const picker = fakePicker(options.pick ?? jpeg());
  const uploader = fakeUploader(options.uploads);
  const handlers = { onResult: jest.fn(), onManual: jest.fn(), onHistory: jest.fn(), onOpenSettings: jest.fn(), openDeviceSettings: jest.fn() };
  const element = <CameraScreen api={ctx.api} picker={picker} photos={createPendingPhotos(files.fs)} uploader={uploader} newId={() => "req-1"} {...handlers} />;
  const startBodies = () => ctx.calls.filter((call) => call.key === "POST /api/v1/food_entries/uploads").map((call) => JSON.parse(call.init.body as string));
  return { ...ctx, ...handlers, files, picker, uploader, element, startBodies };
}

describe("CameraScreen", () => {
  it("camera permission denied shows settings link and manual entry", async () => {
    const { element, picker, openDeviceSettings, onManual } = setup({ pick: { kind: "denied", canAskAgain: false } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(picker.takePhoto).toHaveBeenCalledTimes(1);
    expect(await screen.findByText(/Sem acesso à câmera/)).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Abrir os ajustes do aparelho" }));
    expect(openDeviceSettings).toHaveBeenCalledTimes(1);
    await fireEvent.press(screen.getByRole("link", { name: "Registrar sem foto" }));
    expect(onManual).toHaveBeenCalledTimes(1);
  });

  it("network failure keeps the local copy and retries with the same client_request_id", async () => {
    const { element, files, uploader, startBodies, onResult } = setup({ uploads: [{ ok: false, network: true }] });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(await screen.findByText(/Não foi possível enviar a foto/)).toBeOnTheScreen();
    expect(files.pending().sort()).toEqual(["file:///docs/pending-photos/req-1", "file:///docs/pending-photos/req-1.json"]);
    expect(onResult).not.toHaveBeenCalled();

    await fireEvent.press(screen.getByRole("button", { name: "Tentar enviar de novo" }));

    await waitFor(() => expect(onResult).toHaveBeenCalledWith(ENTRY_ID));
    expect(startBodies().map((body) => body.client_request_id)).toEqual(["req-1", "req-1"]);
    expect(uploader.put).toHaveBeenCalledTimes(2);
    expect(files.pending()).toEqual([]);
  });

  it("sends the signed headers exactly as given", async () => {
    const { element, uploader, startBodies } = setup();
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Escolher da galeria" }));

    await waitFor(() => expect(uploader.put).toHaveBeenCalled());
    expect(uploader.put).toHaveBeenCalledWith("https://storage.test/signed-secret", "file:///docs/pending-photos/req-1", {
      "Content-Type": "image/jpeg",
      "Content-Length": "1000",
    });
    expect(startBodies()[0]).toMatchObject({ client_request_id: "req-1", content_type: "image/jpeg", byte_size: 1000 });
    expect(startBodies()[0].meal_at).toMatch(/Z$|[+-]\d\d:\d\d$/);
  });

  it("skips the upload when the server says the photo is already past it", async () => {
    const { element, uploader, onResult, calls } = setup({ routes: { "POST /api/v1/food_entries/uploads": uploadGrant({ upload_url: null, upload_headers: null, expires_at: null }, 200) } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    await waitFor(() => expect(onResult).toHaveBeenCalledWith(ENTRY_ID));
    expect(uploader.put).not.toHaveBeenCalled();
    expect(calls.filter((call) => call.key.endsWith("/analysis"))).toHaveLength(1);
  });

  it("does not ask for analysis again when the replayed meal is already processing", async () => {
    const { element, onResult, calls } = setup({
      routes: { "POST /api/v1/food_entries/uploads": uploadGrant({ status: "processing", upload_url: null, upload_headers: null, expires_at: null }, 200) },
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    await waitFor(() => expect(onResult).toHaveBeenCalledWith(ENTRY_ID));
    expect(calls.filter((call) => call.key.endsWith("/analysis"))).toHaveLength(0);
  });

  it("consent screen appears before the first photo", async () => {
    const { element, picker, calls } = setup({ consents: { food_photo_ai: "pending" } });
    await render(element);

    expect(await screen.findByText("Sua foto é enviada ao provedor para identificar os alimentos.")).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Tirar uma foto" })).toBeNull();
    expect(picker.takePhoto).not.toHaveBeenCalled();
    expect(calls.some((call) => call.key === "POST /api/v1/consents")).toBe(false);
  });

  it("grants the consent with the version shown and then offers the camera", async () => {
    const { element, calls } = setup({ consents: { food_photo_ai: "pending" }, routes: { "POST /api/v1/consents": jsonResponse(201, { purpose: "food_photo_ai", state: "granted", current_version: 1, accepted_version: 1, decided_at: "2026-11-13T12:00:00Z" }) } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Concordo e continuar" }));

    expect(await screen.findByRole("button", { name: "Tirar uma foto" })).toBeOnTheScreen();
    const grant = calls.find((call) => call.key === "POST /api/v1/consents");
    expect(JSON.parse(grant?.init.body as string)).toEqual({ purpose: "food_photo_ai", version: 1 });
  });

  it("consent_operator_mismatch sends the person back to the consent screen and keeps the copy", async () => {
    const { element, files } = setup({ routes: { "POST /api/v1/food_entries/uploads": errorResponse(403, "consent_operator_mismatch") } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(await screen.findByRole("button", { name: "Concordo e continuar" })).toBeOnTheScreen();
    expect(files.pending().sort()).toEqual(["file:///docs/pending-photos/req-1", "file:///docs/pending-photos/req-1.json"]);
  });

  it("429 shows when the limit resets and offers manual entry", async () => {
    const { element, onManual, files } = setup({ routes: { "POST /api/v1/food_entries/uploads": errorResponse(429, "analysis_quota_exceeded", { "Retry-After": "7200" }) } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(await screen.findByText(/volta em cerca de 2 horas/)).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("link", { name: "Registrar sem foto" }));
    expect(onManual).toHaveBeenCalledTimes(1);
    expect(files.pending()).toEqual([]);
  });

  it("HEIC from the picker is converted before upload", async () => {
    const heic: PickResult = { kind: "photo", photo: { uri: "file:///cache/photo.heic", mimeType: "image/heic", fileSize: 900, fileName: "photo.heic" } };
    const { element, startBodies, files } = setup({ pick: heic });
    files.seed("file:///cache/photo.heic");
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(await screen.findByText(/Este formato de foto não é aceito/)).toBeOnTheScreen();
    expect(startBodies()).toHaveLength(0);
    expect(files.pending()).toEqual([]);
  });

  it("maps 422 unsupported_media_type to the same message", async () => {
    const { element, files } = setup({ routes: { "POST /api/v1/food_entries/uploads": errorResponse(422, "unsupported_media_type") } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(await screen.findByText(/Este formato de foto não é aceito/)).toBeOnTheScreen();
    expect(files.pending()).toEqual([]);
  });

  it("does nothing when the picker is canceled", async () => {
    const { element, startBodies, onResult } = setup({ pick: { kind: "canceled" } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Escolher da galeria" }));

    expect(startBodies()).toHaveLength(0);
    expect(onResult).not.toHaveBeenCalled();
  });

  it("shows loading and an error with retry while the consents load", async () => {
    const { element } = setup({ routes: { "GET /api/v1/consents": errorResponse(500, "internal_error") } });
    await render(element);

    expect(await screen.findByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });

  it("a kept copy and its metadata survive leaving the screen and are resent with the same id", async () => {
    const first = setup({ uploads: [{ ok: false, network: true }] });
    const view = await render(first.element);
    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));
    await screen.findByText(/Não foi possível enviar a foto/);
    expect(first.files.pending().sort()).toEqual(["file:///docs/pending-photos/req-1", "file:///docs/pending-photos/req-1.json"]);
    await view.unmount();

    const second = setup({ files: first.files });
    await render(second.element);
    await fireEvent.press(await screen.findByRole("button", { name: "Reenviar" }));

    await waitFor(() => expect(second.onResult).toHaveBeenCalledWith(ENTRY_ID));
    expect(second.startBodies().map((body) => body.client_request_id)).toEqual(["req-1"]);
    expect(second.uploader.put).toHaveBeenCalledTimes(1);
    expect(first.files.pending()).toEqual([]);
  });

  it("discard deletes the copy and the metadata file", async () => {
    const first = setup({ uploads: [{ ok: false, network: true }] });
    const view = await render(first.element);
    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));
    await screen.findByText(/Não foi possível enviar a foto/);
    await view.unmount();

    const second = setup({ files: first.files });
    await render(second.element);
    await fireEvent.press(await screen.findByRole("button", { name: "Descartar" }));

    await waitFor(() => expect(screen.queryByRole("button", { name: "Reenviar" })).toBeNull());
    expect(first.files.pending()).toEqual([]);
    expect(second.startBodies()).toHaveLength(0);
  });

  it("does not claim the photo is kept when only the analysis request failed", async () => {
    const down = () => {
      throw new Error("offline");
    };
    const { element, files } = setup({ routes: { "POST /api/v1/food_entries/11111111-1111-4111-8111-111111111111/analysis": down } });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

    expect(await screen.findByText(/A foto já foi enviada/)).toBeOnTheScreen();
    expect(screen.queryByText(/continua guardada/)).toBeNull();
    expect(files.pending()).toEqual([]);
    expect(screen.queryByRole("button", { name: "Reenviar" })).toBeNull();
  });
});
