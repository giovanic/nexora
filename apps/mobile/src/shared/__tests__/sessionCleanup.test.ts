import * as SecureStore from "expo-secure-store";
import { session } from "../session";
import { clearPendingPhotos } from "../PendingPhotos";

jest.mock("expo-secure-store", () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));
jest.mock("../PendingPhotos", () => ({ clearPendingPhotos: jest.fn(async () => {}) }));

describe("session cleanup", () => {
  it("clearing the session retries the cleanup of pending photos, even when the keystore fails", async () => {
    (SecureStore.deleteItemAsync as jest.Mock).mockRejectedValue(new Error("keystore"));

    await session.clear();

    expect(clearPendingPhotos).toHaveBeenCalledTimes(1);
  });
});
