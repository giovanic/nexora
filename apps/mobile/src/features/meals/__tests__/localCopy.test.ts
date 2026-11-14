import * as FileSystem from "expo-file-system/legacy";
import * as SecureStore from "expo-secure-store";
import { createApi } from "../../../shared/api";
import { session } from "../../../shared/session";
import { jsonResponse } from "../../../shared/testing/fakes";
import { fakeFs } from "../../../shared/testing/mealFakes";
import { createPendingPhotos } from "../PendingPhotos";

jest.mock("expo-secure-store", () => ({ getItemAsync: jest.fn(async () => "tok"), setItemAsync: jest.fn(), deleteItemAsync: jest.fn() }));
jest.mock("expo-file-system/legacy", () => ({
  documentDirectory: "file:///docs/",
  makeDirectoryAsync: jest.fn(async () => {}),
  copyAsync: jest.fn(async () => {}),
  deleteAsync: jest.fn(async () => {}),
  getInfoAsync: jest.fn(async () => ({ exists: false })),
  uploadAsync: jest.fn(),
  FileSystemUploadType: { BINARY_CONTENT: 0 },
}));

const fsMock = FileSystem as jest.Mocked<typeof FileSystem>;

describe("local copy", () => {
  beforeEach(() => jest.clearAllMocks());

  it("local copy is deleted after upload, on sign out and on account deletion", async () => {
    // After the upload: the copy goes, others stay until their own upload ends.
    const files = fakeFs();
    files.seed("file:///cache/a.jpg");
    const photos = createPendingPhotos(files.fs);
    await photos.save("req-a", "file:///cache/a.jpg");
    await photos.save("req-b", "file:///cache/a.jpg");
    expect(files.pending()).toHaveLength(2);
    await photos.remove("req-a");
    expect(files.pending()).toEqual(["file:///docs/pending-photos/req-b"]);

    // On sign out and on account deletion, through the real session.
    const fetchFn = jest.fn(async () => jsonResponse(204) as unknown as Response);
    const api = createApi({ baseUrl: "http://api.test", fetchFn, session, deviceLabel: "x" });

    await api.signOut();
    expect(fsMock.deleteAsync).toHaveBeenCalledWith("file:///docs/pending-photos/", { idempotent: true });
    expect(SecureStore.deleteItemAsync).toHaveBeenCalledWith("session_token");

    fsMock.deleteAsync.mockClear();
    const deleted = await api.deleteAccount("senha");
    expect(deleted.ok).toBe(true);
    expect(fsMock.deleteAsync).toHaveBeenCalledWith("file:///docs/pending-photos/", { idempotent: true });
  });

  it("clearing never fails the sign out when the folder cannot be removed", async () => {
    fsMock.deleteAsync.mockRejectedValueOnce(new Error("disk"));

    await expect(session.clear()).resolves.toBeUndefined();
    expect(SecureStore.deleteItemAsync).toHaveBeenCalled();
  });
});
