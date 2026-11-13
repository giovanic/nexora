import pkg from "../../../package.json";
import * as SecureStore from "expo-secure-store";
import { session } from "../session";

jest.mock("expo-secure-store", () => ({
  getItemAsync: jest.fn(),
  setItemAsync: jest.fn(),
  deleteItemAsync: jest.fn(),
}));

const store = SecureStore as jest.Mocked<typeof SecureStore>;

describe("session", () => {
  beforeEach(() => jest.clearAllMocks());

  it("stores the token only in SecureStore", async () => {
    store.getItemAsync.mockResolvedValue("abc");

    expect(await session.setToken("abc")).toBe(true);
    expect(store.setItemAsync).toHaveBeenCalledWith("session_token", "abc");
    expect(await session.getToken()).toBe("abc");
    expect(store.getItemAsync).toHaveBeenCalledWith("session_token");

    await session.clear();
    expect(store.deleteItemAsync).toHaveBeenCalledWith("session_token");

    // No plain-storage package is installed to keep a token in.
    const dependencies = Object.keys({ ...pkg.dependencies, ...pkg.devDependencies });
    expect(dependencies.filter((name) => /async-storage|mmkv/.test(name))).toEqual([]);
  });

  it("never throws when SecureStore fails", async () => {
    store.getItemAsync.mockRejectedValue(new Error("keystore"));
    store.setItemAsync.mockRejectedValue(new Error("keystore"));
    store.deleteItemAsync.mockRejectedValue(new Error("keystore"));

    expect(await session.getToken()).toBeNull();
    expect(await session.setToken("abc")).toBe(false);
    await expect(session.clear()).resolves.toBeUndefined();
  });
});
