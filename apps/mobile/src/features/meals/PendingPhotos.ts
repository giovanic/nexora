import * as FileSystem from "expo-file-system/legacy";

// Photos wait here, named by client_request_id, until the upload ends. The folder
// is inside the app's own storage. Every call is safe to await.
export type PendingFs = {
  documentDirectory: string | null;
  makeDirectoryAsync: (uri: string, options?: { intermediates?: boolean }) => Promise<void>;
  copyAsync: (options: { from: string; to: string }) => Promise<void>;
  deleteAsync: (uri: string, options?: { idempotent?: boolean }) => Promise<void>;
  getInfoAsync: (uri: string) => Promise<{ exists: boolean; size?: number }>;
};

const FOLDER = "pending-photos/";
const safe = (id: string) => id.replace(/[^A-Za-z0-9_-]/g, "_");

export function createPendingPhotos(fs: PendingFs) {
  const folder = () => {
    if (!fs.documentDirectory) throw new Error("no document directory");
    return `${fs.documentDirectory}${FOLDER}`;
  };
  const uriFor = (id: string) => `${folder()}${safe(id)}`;

  return {
    uriFor,
    // Copies the picked file into the folder. Returns the local URI, or null if it failed.
    async save(id: string, sourceUri: string): Promise<string | null> {
      try {
        await fs.makeDirectoryAsync(folder(), { intermediates: true });
        const target = uriFor(id);
        const existing = await fs.getInfoAsync(target);
        if (!existing.exists) await fs.copyAsync({ from: sourceUri, to: target });
        return target;
      } catch {
        return null;
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
  getInfoAsync: async (uri) => {
    const info = await FileSystem.getInfoAsync(uri);
    return info.exists ? { exists: true, size: info.size } : { exists: false };
  },
};

export const pendingPhotos = createPendingPhotos(deviceFs);

export const clearPendingPhotos = () => pendingPhotos.clear();
