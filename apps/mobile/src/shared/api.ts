import type { components } from "@app/contracts";
import { session as defaultSession, type Session } from "./session";

type Schemas = components["schemas"];
export type Consent = Schemas["Consent"];
export type ConsentPurpose = Schemas["ConsentPurpose"];
export type ConsentText = Schemas["ConsentText"];
export type DeviceSession = Schemas["DeviceSession"];
export type Motivation = Schemas["Motivation"];
export type Profile = Schemas["Profile"];
export type Sport = Schemas["Sport"];
export type SportLevel = Schemas["SportLevel"];
export type SportProfile = Schemas["SportProfile"];

export type Failure = { ok: false; status: number; code: string; retryAfter?: number };
export type Result<T> = { ok: true; status: number; data: T } | Failure;

type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

export type ApiOptions = {
  baseUrl: string | undefined;
  fetchFn?: FetchFn;
  session?: Session;
  // Called after a session problem (expired, revoked, missing): go to sign in.
  onUnauthorized?: () => void;
  sleep?: (ms: number) => Promise<void>;
  timeoutMs?: number;
};

const REQUEST_TIMEOUT_MS = 15_000;
// profile_pending: the profile is created a moment after sign up.
const PROFILE_RETRY_BUDGET_MS = 10_000;
const PROFILE_RETRY_FIRST_MS = 500;
const PROFILE_RETRY_MAX_MS = 2_000;

const defaultSleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

const failure = (status: number, code: string): Failure => ({ ok: false, status, code });

type RequestOptions = { body?: unknown; auth?: boolean };

export function createApi(options: ApiOptions) {
  const { baseUrl, session = defaultSession, onUnauthorized, timeoutMs = REQUEST_TIMEOUT_MS } = options;
  const fetchFn: FetchFn = options.fetchFn ?? ((url, init) => fetch(url, init));
  const sleep = options.sleep ?? defaultSleep;

  async function expire() {
    // Clearing never blocks the redirect: the person must always reach sign in.
    try {
      await session.clear();
    } catch {
      // ignored on purpose
    }
    onUnauthorized?.();
  }

  async function request<T>(method: string, path: string, { body, auth = true }: RequestOptions = {}): Promise<Result<T>> {
    if (!baseUrl) return failure(0, "network_error");

    const headers: Record<string, string> = { Accept: "application/json" };
    if (body !== undefined) headers["Content-Type"] = "application/json";

    if (auth) {
      const token = await session.getToken();
      if (!token) {
        await expire();
        return failure(401, "unauthorized");
      }
      headers.Authorization = `Bearer ${token}`;
    }

    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const timedOut = new Promise<never>((_, reject) => {
      timer = setTimeout(() => {
        controller.abort();
        reject(new Error("timed out"));
      }, timeoutMs);
    });

    let response: Response;
    try {
      response = await Promise.race([
        fetchFn(`${baseUrl}${path}`, {
          method,
          headers,
          body: body === undefined ? undefined : JSON.stringify(body),
          signal: controller.signal,
        }),
        timedOut,
      ]);
    } catch {
      return failure(0, "network_error");
    } finally {
      clearTimeout(timer);
    }

    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      payload = undefined;
    }

    if (response.ok) return { ok: true, status: response.status, data: payload as T };

    const code = (payload as { error?: { code?: unknown } } | undefined)?.error?.code;
    const result: Failure = failure(response.status, typeof code === "string" ? code : "request_error");
    const retryAfter = Number(response.headers?.get?.("Retry-After"));
    if (Number.isFinite(retryAfter) && retryAfter > 0) result.retryAfter = retryAfter;

    // A wrong password (sign in, account deletion) is also a 401, but the session is fine.
    if (response.status === 401 && auth && result.code !== "invalid_credentials") await expire();

    return result;
  }

  async function whilePending<T>(call: () => Promise<Result<T>>): Promise<Result<T>> {
    let waited = 0;
    let delay = PROFILE_RETRY_FIRST_MS;
    for (;;) {
      const result = await call();
      if (result.ok || result.code !== "profile_pending" || waited + delay > PROFILE_RETRY_BUDGET_MS) return result;
      await sleep(delay);
      waited += delay;
      delay = Math.min(delay * 2, PROFILE_RETRY_MAX_MS);
    }
  }

  async function openSession(path: string, body: unknown): Promise<Result<Schemas["SessionGrant"]>> {
    const result = await request<Schemas["SessionGrant"]>("POST", path, { body, auth: false });
    if (!result.ok) return result;
    const token = result.data.token;
    if (!token || !(await session.setToken(token))) return failure(0, "session_store_failed");
    return result;
  }

  return {
    signUp: (input: { email: string; password: string; timeZone: string }) =>
      openSession("/api/v1/registrations", {
        email: input.email,
        password: input.password,
        adult_confirmed: true,
        time_zone: input.timeZone,
        client: "mobile",
      }),
    signIn: (email: string, password: string) => openSession("/api/v1/sessions", { email, password, client: "mobile" }),
    requestPasswordReset: (email: string) => request<undefined>("POST", "/api/v1/password_resets", { body: { email }, auth: false }),
    signOut: async () => {
      const result = await request<undefined>("DELETE", "/api/v1/sessions/current");
      await session.clear();
      return result;
    },
    listSessions: () => request<Schemas["SessionList"]>("GET", "/api/v1/sessions"),
    revokeSession: (id: string) => request<undefined>("DELETE", `/api/v1/sessions/${encodeURIComponent(id)}`),
    deleteAccount: async (password: string) => {
      const result = await request<undefined>("DELETE", "/api/v1/account", { body: { password } });
      if (result.ok) await session.clear();
      return result;
    },
    listConsents: () => request<Schemas["ConsentList"]>("GET", "/api/v1/consents"),
    getConsentText: (purpose: ConsentPurpose) => request<ConsentText>("GET", `/api/v1/consents/${purpose}/text`),
    grantConsent: (purpose: ConsentPurpose, version: number) =>
      request<Consent>("POST", "/api/v1/consents", { body: { purpose, version } }),
    revokeConsent: (purpose: ConsentPurpose) => request<undefined>("DELETE", `/api/v1/consents/${purpose}`),
    getProfile: () => whilePending(() => request<Profile>("GET", "/api/v1/profile")),
    updateProfile: (changes: Schemas["ProfileUpdate"]) =>
      whilePending(() => request<Profile>("PATCH", "/api/v1/profile", { body: changes })),
    listSportProfiles: () => whilePending(() => request<Schemas["SportProfileList"]>("GET", "/api/v1/sport_profiles")),
    setSportProfile: (sport: Sport, level: SportLevel) =>
      whilePending(() => request<SportProfile>("POST", "/api/v1/sport_profiles", { body: { sport, level } })),
    removeSportProfile: (id: string) =>
      whilePending(() => request<undefined>("DELETE", `/api/v1/sport_profiles/${encodeURIComponent(id)}`)),
  };
}

export type Api = ReturnType<typeof createApi>;

// The app-wide client. The root layout installs the redirect to sign in.
let unauthorizedHandler: (() => void) | undefined;

export function setUnauthorizedHandler(handler: (() => void) | undefined) {
  unauthorizedHandler = handler;
}

export const api: Api = createApi({
  baseUrl: process.env.EXPO_PUBLIC_API_URL,
  onUnauthorized: () => unauthorizedHandler?.(),
});
