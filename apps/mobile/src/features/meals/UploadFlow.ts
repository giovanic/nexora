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

const ALLOWED = ["image/jpeg", "image/png", "image/webp"] as const;
type ContentType = (typeof ALLOWED)[number];

const BY_EXTENSION: Record<string, ContentType> = { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp" };

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

export type PrepareResult = { kind: "prepared"; prepared: Prepared } | { kind: "unsupported" } | { kind: "copy_failed" };

export type SendResult =
  | { kind: "sent"; entryId: string }
  // The photo (or the answer) did not get through; try again with the same id.
  // copyKept is false when the upload had already finished and only the analysis request failed.
  | { kind: "network"; copyKept: boolean }
  | { kind: "failure"; failure: Failure };

// After these the copy is kept: the photo is fine, and it is sent once the person agrees to the consent in force.
const KEEP_COPY = new Set(["consent_required", "consent_operator_mismatch"]);

type Deps = { api: Api; photos: PendingPhotos; uploader: Uploader; newId: () => string; now?: () => Date };

export function createUploadFlow({ api, photos, uploader, newId, now = () => new Date() }: Deps) {
  async function prepare(photo: PickedPhoto): Promise<PrepareResult> {
    const contentType = contentTypeOf(photo);
    if (!contentType) return { kind: "unsupported" };

    const clientRequestId = newId();
    if (!(await photos.save(clientRequestId, photo.uri))) return { kind: "copy_failed" };
    const byteSize = (await photos.size(clientRequestId)) ?? photo.fileSize ?? 0;
    const prepared: Prepared = { clientRequestId, contentType, byteSize, mealAt: now().toISOString() };
    await photos.saveMeta(prepared);
    return { kind: "prepared", prepared };
  }

  async function fail(prepared: Prepared, failure: Failure): Promise<SendResult> {
    if (failure.code === "network_error") return { kind: "network", copyKept: await photos.exists(prepared.clientRequestId) };
    if (!KEEP_COPY.has(failure.code)) await photos.remove(prepared.clientRequestId);
    return { kind: "failure", failure };
  }

  async function send(prepared: Prepared): Promise<SendResult> {
    const started = await api.startFoodUpload({
      client_request_id: prepared.clientRequestId,
      content_type: prepared.contentType,
      byte_size: prepared.byteSize,
      meal_at: prepared.mealAt,
    });
    if (!started.ok) return fail(prepared, started);

    const { food_entry_id: entryId, status, upload_url: url, upload_headers: headers } = started.data;

    if (url) {
      const put = await uploader.put(url, photos.uriFor(prepared.clientRequestId), headers ?? {});
      if (!put.ok) return { kind: "network", copyKept: true };
      await photos.remove(prepared.clientRequestId);
    } else {
      // Replay after the upload: nothing more to send, the copy is not needed.
      await photos.remove(prepared.clientRequestId);
    }

    // A meal already being analyzed or done needs no new request.
    if (status === "processing" || status === "analyzed" || status === "confirmed") return { kind: "sent", entryId };

    const asked = await api.requestFoodAnalysis(entryId);
    // 409 entry_not_analyzable: it is already running or done; the result screen shows where it is.
    if (!asked.ok && asked.status !== 409) return fail(prepared, asked);
    return { kind: "sent", entryId };
  }

  return { prepare, send };
}

export type UploadFlow = ReturnType<typeof createUploadFlow>;
