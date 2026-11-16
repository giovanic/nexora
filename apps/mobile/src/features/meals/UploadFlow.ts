import * as FileSystem from "expo-file-system/legacy";
import type { Api, Failure } from "../../shared/api";
import type { PendingMeta, PendingPhotos } from "../../shared/PendingPhotos";
import type { PickedPhoto } from "./devicePicker";

export type PutResult = { ok: true } | { ok: false; network: boolean };

export type Uploader = {
  // PUTs the file bytes with exactly the signed headers. Never logs the URL or the headers.
  put: (url: string, fileUri: string, headers: Record<string, string>) => Promise<PutResult>;
};

export const deviceUploader: Uploader = {
  async put(url, fileUri, headers) {
    try {
      const response = await FileSystem.uploadAsync(url, fileUri, {
        httpMethod: "PUT",
        uploadType: FileSystem.FileSystemUploadType.BINARY_CONTENT,
        headers,
      });
      return response.status >= 200 && response.status < 300 ? { ok: true } : { ok: false, network: false };
    } catch {
      return { ok: false, network: true };
    }
  },
};

const ALLOWED = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"] as const;
type ContentType = (typeof ALLOWED)[number];

const BY_EXTENSION: Record<string, ContentType> = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp", heic: "image/heic", heif: "image/heif" };

function contentTypeOf(photo: PickedPhoto): ContentType | null {
  const declared = photo.mimeType?.toLowerCase();
  if (declared) {
    const type = declared === "image/jpg" ? "image/jpeg" : declared;
    return (ALLOWED as readonly string[]).includes(type) ? (type as ContentType) : null;
  }
  const extension = (photo.fileName ?? photo.uri).split("?")[0].split(".").pop()?.toLowerCase() ?? "";
  return BY_EXTENSION[extension] ?? null;
}

// What one photo needs to be sent again with the same client_request_id.
export type Prepared = PendingMeta;

export const MAX_PHOTO_BYTES = 10 * 1024 * 1024;

export type PrepareResult = { kind: "prepared"; prepared: Prepared } | { kind: "unsupported" } | { kind: "too_large" } | { kind: "copy_failed" };

export type SendResult =
  | { kind: "sent"; entryId: string }
  // The photo (or the answer) did not get through; try again with `prepared`, which carries
  // the id in force (a new one when the upload had expired).
  // copyKept is false when the upload had already finished and only the analysis request failed.
  | { kind: "network"; copyKept: boolean; prepared: Prepared }
  | { kind: "failure"; failure: Failure };

// The copy is erased only after a definitive answer: the photo can never be sent, or the session ended.
// Everything else (5xx, 429, consent, a failed network) keeps it, so the photo is never lost.
const DEFINITIVE_CODES = new Set(["invalid_photo", "unauthorized", "analysis_retry_limit"]);
const isDefinitive = (failure: Failure) => failure.status === 422 || failure.status === 401 || failure.status === 404 || DEFINITIVE_CODES.has(failure.code);
const settled = (status: string) => status === "processing" || status === "analyzed" || status === "confirmed";

type Deps = { api: Api; photos: PendingPhotos; uploader: Uploader; newId: () => string; now?: () => Date };

export function createUploadFlow({ api, photos, uploader, newId, now = () => new Date() }: Deps) {
  async function prepare(photo: PickedPhoto): Promise<PrepareResult> {
    const contentType = contentTypeOf(photo);
    if (!contentType) return { kind: "unsupported" };

    const clientRequestId = newId();
    if (!(await photos.save(clientRequestId, photo.uri))) return { kind: "copy_failed" };
    const byteSize = (await photos.size(clientRequestId)) ?? photo.fileSize ?? 0;
    if (byteSize > MAX_PHOTO_BYTES) {
      await photos.remove(clientRequestId);
      return { kind: "too_large" };
    }
    const prepared: Prepared = { clientRequestId, contentType, byteSize, mealAt: now().toISOString() };
    await photos.saveMeta(prepared);
    return { kind: "prepared", prepared };
  }

  async function fail(prepared: Prepared, failure: Failure): Promise<SendResult> {
    if (failure.code === "network_error") return { kind: "network", copyKept: await photos.exists(prepared.clientRequestId), prepared };
    if (isDefinitive(failure)) await photos.remove(prepared.clientRequestId);
    return { kind: "failure", failure };
  }

  // renewed: an expired upload is started again once, with a new id, from the same local copy.
  async function send(prepared: Prepared, renewed = false): Promise<SendResult> {
    const started = await api.startFoodUpload({
      client_request_id: prepared.clientRequestId,
      content_type: prepared.contentType,
      byte_size: prepared.byteSize,
      meal_at: prepared.mealAt,
    });
    if (!started.ok && started.code === "upload_expired") {
      const next: Prepared = { ...prepared, clientRequestId: newId() };
      if (renewed || !(await photos.rename(prepared.clientRequestId, next.clientRequestId))) {
        await photos.remove(prepared.clientRequestId);
        return { kind: "failure", failure: { ok: false, status: 422, code: "not_uploaded" } };
      }
      await photos.saveMeta(next);
      return send(next, true);
    }
    if (!started.ok) return fail(prepared, started);

    const { food_entry_id: entryId, status, upload_url: url, upload_headers: headers } = started.data;

    if (url) {
      let localUri: string;
      try {
        localUri = photos.uriFor(prepared.clientRequestId);
      } catch {
        return { kind: "failure", failure: { ok: false, status: 422, code: "not_uploaded" } };
      }
      const put = await uploader.put(url, localUri, headers ?? {});
      if (!put.ok) return { kind: "network", copyKept: true, prepared };
      await photos.remove(prepared.clientRequestId);
    } else if (settled(status)) {
      // Replay after the upload: nothing more to send, the copy is not needed.
      await photos.remove(prepared.clientRequestId);
    }

    // A meal already being analyzed or done needs no new request.
    if (settled(status)) return { kind: "sent", entryId };

    const asked = await api.requestFoodAnalysis(entryId);
    // 409 entry_not_analyzable: it is already running or done; the result screen shows where it is.
    if (!asked.ok && !(asked.status === 409 && asked.code === "entry_not_analyzable")) return fail(prepared, asked);
    await photos.remove(prepared.clientRequestId);
    return { kind: "sent", entryId };
  }

  return { prepare, send };
}

export type UploadFlow = ReturnType<typeof createUploadFlow>;
