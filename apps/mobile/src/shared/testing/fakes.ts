// Test helpers only. Nothing here is imported by a route or a screen.
import { createApi } from "../api";
import type { Session } from "../session";

export type ResponseLike = {
  ok: boolean;
  status: number;
  headers: { get: (name: string) => string | null };
  json: () => Promise<unknown>;
};

export function jsonResponse(status: number, body?: unknown, headers: Record<string, string> = {}): ResponseLike {
  return {
    ok: status < 400,
    status,
    headers: { get: (name) => headers[name] ?? null },
    json: async () => {
      if (body === undefined) throw new SyntaxError("no body");
      return body;
    },
  };
}

export function errorResponse(status: number, code: string, headers: Record<string, string> = {}): ResponseLike {
  return jsonResponse(status, { error: { code, message: "mensagem do servidor", request_id: "req-1" } }, headers);
}

export type Route = ResponseLike | ((init: RequestInit) => ResponseLike | Promise<ResponseLike>);

export function fakeSession(token: string | null = "token-de-teste"): Session & {
  getToken: jest.Mock;
  setToken: jest.Mock;
  clear: jest.Mock;
} {
  let current = token;
  return {
    getToken: jest.fn(async () => current),
    setToken: jest.fn(async (value: string) => {
      current = value;
      return true;
    }),
    clear: jest.fn(async () => {
      current = null;
    }),
  };
}

// Builds the real client over a fake network. Routes are keyed "METHOD /path".
export function makeApi(routes: Record<string, Route>, token: string | null = "token-de-teste") {
  const calls: { key: string; init: RequestInit }[] = [];
  const fetchFn = jest.fn(async (url: string, init: RequestInit = {}) => {
    const key = `${init.method ?? "GET"} ${url.replace("http://api.test", "")}`;
    calls.push({ key, init });
    const route = routes[key];
    if (!route) throw new Error(`unrouted request: ${key}`);
    return (typeof route === "function" ? await route(init) : route) as unknown as Response;
  });
  const session = fakeSession(token);
  const onUnauthorized = jest.fn();
  const sleep = jest.fn(async (_ms: number) => {});
  const api = createApi({ baseUrl: "http://api.test", fetchFn, session, onUnauthorized, sleep, deviceLabel: "Aparelho de teste" });
  return { api, fetchFn, session, onUnauthorized, sleep, calls };
}

export const consentList = (states: Partial<Record<string, string>> = {}) =>
  jsonResponse(200, {
    consents: ["health_data", "food_photo_ai", "strava_integration", "usage_metrics"].map((purpose) => ({
      purpose,
      state: states[purpose] ?? "pending",
      current_version: 1,
      accepted_version: states[purpose] === "granted" ? 1 : null,
      decided_at: null,
    })),
  });
