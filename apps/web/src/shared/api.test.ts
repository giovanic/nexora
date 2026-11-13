import { beforeEach, describe, expect, it, vi } from "vitest";
import { createApi } from "./api";
import { errorBody, fakeFetch } from "./testing";

beforeEach(() => {
  localStorage.clear();
  sessionStorage.clear();
});

describe("createApi", () => {
  it("signs in as the web client, with credentials and no Authorization header", async () => {
    const fetchFn = fakeFetch({ "POST /api/v1/sessions": { status: 201, body: { user_id: "u", expires_at: "2026-12-01T00:00:00Z" } } });
    const api = createApi({ baseUrl: "", fetchFn });

    const result = await api.signIn("ana@example.com", "a long password");

    expect(result.ok).toBe(true);
    const init = fetchFn.mock.calls[0][1] as RequestInit;
    expect(init.credentials).toBe("include");
    expect(JSON.parse(init.body as string)).toEqual({ email: "ana@example.com", password: "a long password", client: "web" });
    expect(Object.keys(init.headers as object)).not.toContain("Authorization");
  });

  it("sends the person to sign in on a session problem, but not on a wrong password", async () => {
    const onUnauthorized = vi.fn();
    const fetchFn = fakeFetch({
      "GET /api/v1/consents": { status: 401, body: errorBody("unauthorized") },
      "POST /api/v1/account/export": { status: 401, body: errorBody("invalid_credentials") },
    });
    const api = createApi({ baseUrl: "", fetchFn, onUnauthorized });

    await api.exportAccount("wrong");
    expect(onUnauthorized).not.toHaveBeenCalled();

    const result = await api.listConsents();
    expect(result).toMatchObject({ ok: false, status: 401, code: "unauthorized" });
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  it("treats a 200 that is not JSON as bad_response, not as data", async () => {
    const fetchFn = vi.fn(async () => new Response("<!doctype html>", { status: 200 }));
    const api = createApi({ baseUrl: "", fetchFn });
    expect(await api.listConsents()).toMatchObject({ ok: false, code: "bad_response" });
  });

  it("reports rate limits and network failures", async () => {
    const fetchFn = fakeFetch({ "POST /api/v1/sessions": { status: 429, body: errorBody("rate_limited"), headers: { "Retry-After": "60" } } });
    const api = createApi({ baseUrl: "", fetchFn });

    expect(await api.signIn("a@b.c", "x")).toMatchObject({ ok: false, status: 429, retryAfter: 60 });

    const down = createApi({ baseUrl: "", fetchFn: vi.fn(async () => { throw new TypeError("down"); }) });
    expect(await down.signIn("a@b.c", "x")).toMatchObject({ ok: false, status: 0, code: "network_error" });
  });
});
