import * as SecureStore from "expo-secure-store";

// The session token lives only in the device keystore (SecureStore), never in
// plain storage, logs or monitoring. Every call is safe to await: a keystore
// failure becomes "no token" or "not stored", never an exception.
export const TOKEN_KEY = "session_token";

export type Session = {
  getToken: () => Promise<string | null>;
  setToken: (token: string) => Promise<boolean>;
  clear: () => Promise<void>;
};

export const session: Session = {
  async getToken() {
    try {
      return (await SecureStore.getItemAsync(TOKEN_KEY)) ?? null;
    } catch {
      return null;
    }
  },
  async setToken(token) {
    try {
      await SecureStore.setItemAsync(TOKEN_KEY, token);
      return true;
    } catch {
      return false;
    }
  },
  async clear() {
    try {
      await SecureStore.deleteItemAsync(TOKEN_KEY);
    } catch {
      // Nothing more to do: the caller goes to sign in either way.
    }
  },
};
