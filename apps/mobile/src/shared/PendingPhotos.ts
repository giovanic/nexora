import * as FileSystem from "expo-file-system/legacy";

// Photos wait here, named by client_request_id, until the upload ends. The folder
// is inside the app's own storage. Every call is safe to await.
export type PendingFs = {
  documentDirectory: string | null;
  makeDirectoryAsync: (uri: string, options?: { intermediates?: boolean }) => Promise<void>;
  copyAsync: (options: { from: string; to: string }) => Promise<void>;
  deleteAsync: (uri: string, options?: { idempotent?: boolean }) => Promise<void>;
  getInfoAsync: (uri: string) => Promise<{ exists: boolean; size?: number }>;
  writeAsStringAsync: (uri: string, contents: string) => Promise<void>;
  readAsStringAsync: (uri: string) => Promise<string>;
  readDirectoryAsync: (uri: string) => Promise<string[]>;
};

// The minimum needed to send a kept photo again with the same client_request_id.
// No food data, no URLs: only what the upload request itself carries.
export type PendingMeta = {
  clientRequestId: string;
  contentType: "image/jpeg" | "image/png" | "image/webp" | "image/heic" | "image/heif";
  byteSize: number;
  mealAt: string;
};

const TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];
const META_SUFFIX = ".json";

function parseMeta(text: string): PendingMeta | null {
  try {
    const value = JSON.parse(text) as Partial<PendingMeta>;
    if (
      typeof value.clientRequestId === "string" &&
      typeof value.contentType === "string" &&
      TYPES.includes(value.contentType) &&
      typeof value.byteSize === "number" &&
      typeof value.mealAt === "string"
    ) {
      return value as PendingMeta;
    }
  } catch {
    // An unreadable file is treated as no metadata.
  }
  return null;
}

const FOLDER = "pending-photos/";
const safe = (id: string) => id.replace(/[^A-Za-z0-9_-]/g, "_");

export function createPendingPhotos(fs: PendingFs) {
  const folder = () => {
    if (!fs.documentDirectory) throw new Error("no document directory");
    return `${fs.documentDirectory}${FOLDER}`;
  };
  const uriFor = (id: string) => `${folder()}${safe(id)}`;
  const metaUri = (id: string) => `${uriFor(id)}${META_SUFFIX}`;

  async function exists(id: string): Promise<boolean> {
    try {
      return (await fs.getInfoAsync(uriFor(id))).exists;
    } catch {
      return false;
    }
  }

  return {
    uriFor,
    // Copies the picked file into the folder. Returns the local URI, or null if it failed.
    async save(id: string, sourceUri: string): Promise<string | null> {
      try {
        await fs.makeDirectoryAsync(folder(), { intermediates: true });
        const target = uriFor(id);
        const existing = await fs.getInfoAsync(target);
        if (!existing.exists) await fs.copyAsync({ from: sourceUri, to: target });
        // The picker's file lives in the cache, outside the app's own folder, and may be backed up
        // or read by other code. Once the copy exists the source is not needed. A failure here
        // never blocks the upload.
        if (sourceUri !== target) await fs.deleteAsync(sourceUri, { idempotent: true }).catch(() => {});
        return target;
      } catch {
        return null;
      }
    },
    // Moves a kept photo to a new id (an expired upload starts over). Returns false when there is no copy.
    async rename(oldId: string, newId: string): Promise<boolean> {
      try {
        if (!(await fs.getInfoAsync(uriFor(oldId))).exists) return false;
        await fs.copyAsync({ from: uriFor(oldId), to: uriFor(newId) });
        await fs.deleteAsync(uriFor(oldId), { idempotent: true });
        await fs.deleteAsync(metaUri(oldId), { idempotent: true });
        return true;
      } catch {
        return false;
      }
    },
    exists,
    async saveMeta(meta: PendingMeta): Promise<void> {
      try {
        await fs.writeAsStringAsync(metaUri(meta.clientRequestId), JSON.stringify(meta));
      } catch {
        // The copy still works for this screen; only a later resend is lost.
      }
    },
    // Copies kept on the device, with the data to send each one again. Metadata
    // without its copy (or the other way round) is not offered and is cleaned up.
    async list(): Promise<PendingMeta[]> {
      try {
        const names = await fs.readDirectoryAsync(folder());
        const found: PendingMeta[] = [];
        for (const name of names.filter((entry) => entry.endsWith(META_SUFFIX))) {
          const meta = parseMeta(await fs.readAsStringAsync(`${folder()}${name}`).catch(() => ""));
          if (meta && (await exists(meta.clientRequestId))) found.push(meta);
          else await fs.deleteAsync(`${folder()}${name}`, { idempotent: true }).catch(() => {});
        }
        return found;
      } catch {
        return [];
      }
    },
    async size(id: string): Promise<number | null> {
      try {
        const info = await fs.getInfoAsync(uriFor(id));
        return info.exists && typeof info.size === "number" ? info.size : null;
      } catch {
        return null;
      }
    },
    async remove(id: string): Promise<void> {
      try {
        await fs.deleteAsync(uriFor(id), { idempotent: true });
        await fs.deleteAsync(metaUri(id), { idempotent: true });
      } catch {
        // A copy left behind is removed on sign out.
      }
    },
    async clear(): Promise<void> {
      try {
        await fs.deleteAsync(folder(), { idempotent: true });
      } catch {
        // Clearing never blocks sign out or account deletion.
      }
    },
  };
}

export type PendingPhotos = ReturnType<typeof createPendingPhotos>;

const deviceFs: PendingFs = {
  get documentDirectory() {
    return FileSystem.documentDirectory;
  },
  makeDirectoryAsync: (uri, options) => FileSystem.makeDirectoryAsync(uri, options),
  copyAsync: (options) => FileSystem.copyAsync(options),
  deleteAsync: (uri, options) => FileSystem.deleteAsync(uri, options),
  writeAsStringAsync: (uri, contents) => FileSystem.writeAsStringAsync(uri, contents),
  readAsStringAsync: (uri) => FileSystem.readAsStringAsync(uri),
  readDirectoryAsync: (uri) => FileSystem.readDirectoryAsync(uri),
  getInfoAsync: async (uri) => {
    const info = await FileSystem.getInfoAsync(uri);
    return info.exists ? { exists: true, size: info.size } : { exists: false };
  },
};

export const pendingPhotos = createPendingPhotos(deviceFs);

export const clearPendingPhotos = () => pendingPhotos.clear();
