import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { consentList, errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { ENTRY_ID, analysisAccepted, fakeFs, fakePicker, fakeUploader, jpeg, uploadGrant } from "../../../shared/testing/mealFakes";
import { CameraScreen } from "../CameraScreen";
import { createPendingPhotos } from "../../../shared/PendingPhotos";
import type { PickResult } from "../devicePicker";

const consentText = jsonResponse(200, { purpose: "food_photo_ai", version: 1, text: "Sua foto é enviada ao provedor para identificar os alimentos." });
const UPLOADS = "POST /api/v1/food_entries/uploads";
const ANALYSIS = `POST /api/v1/food_entries/${ENTRY_ID}/analysis`;
const KEPT = ["file:///docs/pending-photos/req-1", "file:///docs/pending-photos/req-1.json"];

type Options = {
  pick?: PickResult;
  routes?: Record<string, unknown>;
  consents?: Record<string, string>;
  uploads?: Parameters<typeof fakeUploader>[0];
  files?: ReturnType<typeof fakeFs>;
  newId?: () => string;
};

function setup(options: Options = {}) {
  const ctx = makeApi({
    "GET /api/v1/consents": consentList(options.consents ?? { food_photo_ai: "granted" }),
    "GET /api/v1/consents/food_photo_ai/text": consentText,
    [UPLOADS]: uploadGrant(),
    [ANALYSIS]: analysisAccepted(),
    ...options.routes,
  } as never);
  const files = options.files ?? fakeFs();
  files.seed("file:///cache/photo.jpg");
  const picker = fakePicker(options.pick ?? jpeg());
  const uploader = fakeUploader(options.uploads);
  const handlers = { onResult: jest.fn(), onManual: jest.fn(), onHistory: jest.fn(), onOpenSettings: jest.fn(), openDeviceSettings: jest.fn() };
  const element = (
    <CameraScreen api={ctx.api} picker={picker} photos={createPendingPhotos(files.fs)} uploader={uploader} newId={options.newId ?? (() => "req-1")} {...handlers} />
  );
  const startBodies = () => ctx.calls.filter((call) => call.key === UPLOADS).map((call) => JSON.parse(call.init.body as string));
  return { ...ctx, ...handlers, files, picker, uploader, element, startBodies };
}

const takePhoto = async () => fireEvent.press(await screen.findByRole("button", { name: "Tirar uma foto" }));

describe("CameraScreen resilience", () => {
  it("network failure, wait, resend, upload_expired, new id and the photo is sent", async () => {
    const ids = ["req-1", "req-2", "req-3"];
    let next = 0;
    let uploadCalls = 0;
    const route = (init: RequestInit) => {
      const id = JSON.parse(init.body as string).client_request_id;
      uploadCalls += 1;
      return id === "req-1" && uploadCalls > 1 ? errorResponse(409, "upload_expired") : uploadGrant();
    };
    const { element, files, uploader, startBodies, onResult } = setup({ newId: () => ids[next++], uploads: [{ ok: false, network: true }], routes: { [UPLOADS]: route } });
    await render(element);

    await takePhoto();
    expect(await screen.findByText(/Não foi possível enviar a foto/)).toBeOnTheScreen();
    expect(files.pending().sort()).toEqual(KEPT);

    await fireEvent.press(screen.getByRole("button", { name: "Tentar enviar de novo" }));

    await waitFor(() => expect(onResult).toHaveBeenCalledWith(ENTRY_ID));
    expect(startBodies().map((body) => body.client_request_id)).toEqual(["req-1", "req-1", "req-2"]);
    expect(startBodies()[2]).toMatchObject({ content_type: "image/jpeg", byte_size: 1000 });
    expect(uploader.put).toHaveBeenCalledTimes(2);
    expect(uploader.put.mock.calls[1][1]).toBe("file:///docs/pending-photos/req-2");
    expect(files.pending()).toEqual([]);
  });

  it("a second upload_expired in a row ends with a message and no loop", async () => {
    let next = 0;
    const { element, startBodies, files } = setup({ newId: () => `req-${++next}`, routes: { [UPLOADS]: errorResponse(409, "upload_expired") } });
    await render(element);

    await takePhoto();

    expect(await screen.findByText(/Tire outra foto/)).toBeOnTheScreen();
    expect(startBodies()).toHaveLength(2);
    expect(files.pending()).toEqual([]);
  });

  it("a replay without URL keeps the copy while the meal is still pending", async () => {
    const replay = uploadGrant({ status: "pending", upload_url: null, upload_headers: null, expires_at: null }, 200);
    const { element, files } = setup({ routes: { [UPLOADS]: replay, [ANALYSIS]: errorResponse(500, "internal_error") } });
    await render(element);

    await takePhoto();

    expect(await screen.findByText(/Algo deu errado do nosso lado/)).toBeOnTheScreen();
    expect(files.pending().sort()).toEqual(KEPT);
  });

  it("a replay without URL removes the copy once the analysis is accepted", async () => {
    const replay = uploadGrant({ status: "pending", upload_url: null, upload_headers: null, expires_at: null }, 200);
    const { element, files, onResult } = setup({ routes: { [UPLOADS]: replay } });
    await render(element);

    await takePhoto();

    await waitFor(() => expect(onResult).toHaveBeenCalledWith(ENTRY_ID));
    expect(files.pending()).toEqual([]);
  });

  it("right after accepting the consent, a repeated consent_operator_mismatch says photo analysis is not available yet", async () => {
    const { element, files, onManual } = setup({
      consents: { food_photo_ai: "pending" },
      routes: {
        "POST /api/v1/consents": jsonResponse(201, { purpose: "food_photo_ai", state: "granted", current_version: 1, accepted_version: 1, decided_at: "2026-11-13T12:00:00Z" }),
        [UPLOADS]: errorResponse(403, "consent_operator_mismatch"),
      },
    });
    await render(element);
    await fireEvent.press(await screen.findByRole("button", { name: "Concordo e continuar" }));
    await takePhoto();

    expect(await screen.findByText(/A análise por foto ainda não está disponível/)).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Concordo e continuar" })).toBeNull();
    expect(files.pending().sort()).toEqual(KEPT);
    await fireEvent.press(screen.getByRole("link", { name: "Registrar sem foto" }));
    expect(onManual).toHaveBeenCalledTimes(1);
  });

  it("the picker's source file is deleted after the copy", async () => {
    const { element, files, onResult } = setup();
    await render(element);

    await takePhoto();

    await waitFor(() => expect(onResult).toHaveBeenCalled());
    expect(files.fs.deleteAsync).toHaveBeenCalledWith("file:///cache/photo.jpg", { idempotent: true });
    expect(files.files.has("file:///cache/photo.jpg")).toBe(false);
  });

  it("a failure to delete the source does not block the upload", async () => {
    const { element, files, onResult } = setup();
    const original = files.fs.deleteAsync.getMockImplementation();
    files.fs.deleteAsync.mockImplementation(async (uri: string, options?: { idempotent?: boolean }) => {
      if (uri === "file:///cache/photo.jpg") throw new Error("cannot delete");
      return original?.(uri, options);
    });
    await render(element);

    await takePhoto();

    await waitFor(() => expect(onResult).toHaveBeenCalledWith(ENTRY_ID));
  });

  it.each([
    ["500", errorResponse(500, "internal_error"), true],
    ["429", errorResponse(429, "rate_limited", { "Retry-After": "60" }), true],
    ["422 invalid_photo", errorResponse(422, "invalid_photo"), false],
    ["422 validation_failed", errorResponse(422, "validation_failed"), false],
    ["401 unauthorized", errorResponse(401, "unauthorized"), false],
  ])("on %s the copy is kept: %s", async (_name, response, kept) => {
    const { element, files } = setup({ routes: { [UPLOADS]: response } });
    await render(element);

    await takePhoto();

    await waitFor(() => expect(screen.queryByText("Enviando a foto…")).toBeNull());
    expect(files.pending().length > 0).toBe(kept);
  });

  it("an error from the picker never leaves the screen stuck on sending", async () => {
    const { element, picker } = setup();
    picker.takePhoto.mockRejectedValueOnce(new Error("permission service down"));
    await render(element);

    await takePhoto();

    expect(await screen.findByText(/Não foi possível abrir a câmera ou a galeria/)).toBeOnTheScreen();
    expect(screen.queryByText("Enviando a foto…")).toBeNull();
    expect(screen.getByRole("button", { name: "Tirar uma foto" })).toBeOnTheScreen();
  });

  it("refuses a photo over 10 MB before sending, with the size message", async () => {
    const size = 11 * 1024 * 1024;
    const big: PickResult = { kind: "photo", photo: { uri: "file:///cache/photo.jpg", mimeType: "image/jpeg", fileSize: size, fileName: "photo.jpg" } };
    const { element, startBodies, files } = setup({ pick: big });
    files.seed("file:///cache/photo.jpg", size);
    await render(element);

    await takePhoto();

    expect(await screen.findByText(/limite é de 10 MB/)).toBeOnTheScreen();
    expect(startBodies()).toHaveLength(0);
    expect(files.pending()).toEqual([]);
  });

  it("the server's field in validation_failed picks the message", async () => {
    const response = jsonResponse(422, { error: { code: "validation_failed", message: "x", request_id: "r", details: [{ field: "meal_at", code: "out_of_range" }] } });
    const { element } = setup({ routes: { [UPLOADS]: response } });
    await render(element);

    await takePhoto();

    expect(await screen.findByText(/data e a hora da refeição/)).toBeOnTheScreen();
  });

  it("a missing document directory becomes a handled error", async () => {
    const files = fakeFs();
    (files.fs as { documentDirectory: string | null }).documentDirectory = null;
    const { element } = setup({ files });
    await render(element);

    await takePhoto();

    expect(await screen.findByText(/Não foi possível guardar a foto no aparelho/)).toBeOnTheScreen();
  });

  it("the denied-permission message is announced as a status", async () => {
    const { element } = setup({ pick: { kind: "denied", canAskAgain: false } });
    await render(element);

    await takePhoto();

    expect(await screen.findByRole("status")).toHaveTextContent(/Sem acesso à câmera/);
  });
});
