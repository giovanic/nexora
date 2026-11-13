import type { components } from "@app/contracts";

type Schemas = components["schemas"];
export type Consent = Schemas["Consent"];
export type ConsentPurpose = Schemas["ConsentPurpose"];
export type ConsentText = Schemas["ConsentText"];

export type Failure = { ok: false; status: number; code: string; retryAfter?: number };
export type Result<T> = { ok: true; status: number; data: T } | Failure;

export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

export type ApiOptions = {
  // Empty means same origin: the Vite proxy (development) or the same host (production).
  baseUrl: string;
  fetchFn?: FetchFn;
  // Called after a session problem (expired, revoked, missing): go to sign in.
  onUnauthorized?: () => void;
  timeoutMs?: number;
};

const REQUEST_TIMEOUT_MS = 15_000;

const failure = (status: number, code: string): Failure => ({ ok: false, status, code });

// The session lives in the HttpOnly cookie. This client never sees, reads or keeps a token.
export function createApi({ baseUrl, fetchFn, onUnauthorized, timeoutMs = REQUEST_TIMEOUT_MS }: ApiOptions) {
  const send: FetchFn = fetchFn ?? ((url, init) => fetch(url, init));

  async function request<T>(method: string, path: string, body?: unknown): Promise<Result<T>> {
    const headers: Record<string, string> = { Accept: "application/json" };
    if (body !== undefined) headers["Content-Type"] = "application/json";

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
        send(`${baseUrl}${path}`, {
          method,
          headers,
          credentials: "include",
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

    if (response.ok) {
      // 202 and 204 carry no body. Anything else without JSON is not our API answering
      // (a host serving index.html, say), and the screens must not treat it as data.
      const needsBody = response.status !== 202 && response.status !== 204;
      if (needsBody && (typeof payload !== "object" || payload === null)) return failure(response.status, "bad_response");
      return { ok: true, status: response.status, data: payload as T };
    }

    const code = (payload as { error?: { code?: unknown } } | undefined)?.error?.code;
    const result: Failure = failure(response.status, typeof code === "string" ? code : "request_error");
    const retryAfter = Number(response.headers.get("Retry-After"));
    if (Number.isFinite(retryAfter) && retryAfter > 0) result.retryAfter = retryAfter;

    // A wrong password (export, deletion) is also a 401, but the session is fine.
    if (response.status === 401 && result.code !== "invalid_credentials") onUnauthorized?.();

    return result;
  }

  return {
    signIn: (email: string, password: string) =>
      request<Schemas["SessionGrant"]>("POST", "/api/v1/sessions", { email, password, client: "web" }),
    signOut: () => request<undefined>("DELETE", "/api/v1/sessions/current"),
    listConsents: () => request<Schemas["ConsentList"]>("GET", "/api/v1/consents"),
    getConsentText: (purpose: ConsentPurpose) => request<ConsentText>("GET", `/api/v1/consents/${purpose}/text`),
    grantConsent: (purpose: ConsentPurpose, version: number) => request<Consent>("POST", "/api/v1/consents", { purpose, version }),
    revokeConsent: (purpose: ConsentPurpose) => request<undefined>("DELETE", `/api/v1/consents/${purpose}`),
    exportAccount: (password: string) => request<Schemas["AccountExport"]>("POST", "/api/v1/account/export", { password }),
    deleteAccount: (password: string) => request<undefined>("DELETE", "/api/v1/account", { password }),
    resetPassword: (token: string, password: string) =>
      request<undefined>("PATCH", `/api/v1/password_resets/${encodeURIComponent(token)}`, { password }),
  };
}

export type Api = ReturnType<typeof createApi>;
