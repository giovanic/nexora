import { errorResponse, jsonResponse, makeApi } from "../testing/fakes";

const grant = { user_id: "u1", expires_at: "2026-12-01T00:00:00Z", token: "novo-token" };

describe("api client", () => {
  it("sends the stored token as a Bearer header", async () => {
    const { api, calls } = makeApi({ "GET /api/v1/consents": jsonResponse(200, { consents: [] }) });

    const result = await api.listConsents();

    expect(result.ok).toBe(true);
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer token-de-teste");
  });

  it("401 clears the session and goes to sign in", async () => {
    const { api, session, onUnauthorized } = makeApi({ "GET /api/v1/profile": errorResponse(401, "unauthorized") });

    const result = await api.getProfile();

    expect(result).toMatchObject({ ok: false, status: 401, code: "unauthorized" });
    expect(session.clear).toHaveBeenCalledTimes(1);
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  it("still goes to sign in when clearing the store fails", async () => {
    const { api, session, onUnauthorized } = makeApi({ "GET /api/v1/profile": errorResponse(401, "unauthorized") });
    session.clear.mockRejectedValue(new Error("keystore"));

    await api.getProfile();

    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  it("goes to sign in without calling the network when there is no token", async () => {
    const { api, fetchFn, onUnauthorized } = makeApi({}, null);

    await api.listSessions();

    expect(fetchFn).not.toHaveBeenCalled();
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  it("keeps the session on 401 invalid_credentials (wrong password on delete)", async () => {
    const { api, session, onUnauthorized } = makeApi({ "DELETE /api/v1/account": errorResponse(401, "invalid_credentials") });

    const result = await api.deleteAccount("senha-errada-123");

    expect(result).toMatchObject({ ok: false, code: "invalid_credentials" });
    expect(session.clear).not.toHaveBeenCalled();
    expect(onUnauthorized).not.toHaveBeenCalled();
  });

  it("does not clear anything on a wrong password at sign in", async () => {
    const { api, session, onUnauthorized } = makeApi({ "POST /api/v1/sessions": errorResponse(401, "invalid_credentials") });

    const result = await api.signIn("a@x.test", "errada");

    expect(result).toMatchObject({ ok: false, code: "invalid_credentials" });
    expect(session.clear).not.toHaveBeenCalled();
    expect(onUnauthorized).not.toHaveBeenCalled();
  });

  it("stores the token that sign up returns, and asks for the mobile transport", async () => {
    const { api, session, calls } = makeApi({ "POST /api/v1/registrations": jsonResponse(201, grant) }, null);

    const result = await api.signUp({ email: "a@x.test", password: "uma-senha-longa", timeZone: "America/Sao_Paulo" });

    expect(result.ok).toBe(true);
    expect(session.setToken).toHaveBeenCalledWith("novo-token");
    expect(JSON.parse(calls[0].init.body as string)).toEqual({
      email: "a@x.test",
      password: "uma-senha-longa",
      adult_confirmed: true,
      time_zone: "America/Sao_Paulo",
      client: "mobile",
      device_label: "Aparelho de teste",
    });
  });

  it("fails calmly when the token cannot be stored", async () => {
    const { api, session } = makeApi({ "POST /api/v1/sessions": jsonResponse(201, grant) }, null);
    session.setToken.mockResolvedValue(false);

    const result = await api.signIn("a@x.test", "uma-senha-longa");

    expect(result).toMatchObject({ ok: false, code: "session_store_failed" });
  });

  it("retries profile_pending with a backoff, then succeeds", async () => {
    const profile = { display_name: null, time_zone: "UTC", units: "metric", motivations: [] };
    const answers = [errorResponse(409, "profile_pending"), errorResponse(409, "profile_pending"), jsonResponse(200, profile)];
    const { api, sleep, fetchFn } = makeApi({ "GET /api/v1/profile": () => answers.shift()! });

    const result = await api.getProfile();

    expect(result.ok).toBe(true);
    expect(fetchFn).toHaveBeenCalledTimes(3);
    expect(sleep).toHaveBeenCalledTimes(2);
  });

  it("stops retrying profile_pending after about ten seconds", async () => {
    const { api, sleep, fetchFn } = makeApi({ "GET /api/v1/profile": () => errorResponse(409, "profile_pending") });

    const result = await api.getProfile();

    expect(result).toMatchObject({ ok: false, code: "profile_pending" });
    const waited = sleep.mock.calls.reduce((sum, [ms]) => sum + (ms as number), 0);
    expect(waited).toBeLessThanOrEqual(10_000);
    expect(waited).toBeGreaterThanOrEqual(8_000);
    expect(fetchFn.mock.calls.length).toBe(sleep.mock.calls.length + 1);
  });

  it("does not retry revocation_pending", async () => {
    const { api, fetchFn } = makeApi({ "POST /api/v1/consents": errorResponse(409, "revocation_pending") });

    const result = await api.grantConsent("health_data", 1);

    expect(result).toMatchObject({ ok: false, code: "revocation_pending" });
    expect(fetchFn).toHaveBeenCalledTimes(1);
  });

  it("reports Retry-After on 429", async () => {
    const { api } = makeApi({ "POST /api/v1/password_resets": errorResponse(429, "too_many_requests", { "Retry-After": "120" }) });

    const result = await api.requestPasswordReset("a@x.test");

    expect(result).toMatchObject({ ok: false, status: 429, retryAfter: 120 });
  });

  it("turns a network failure into a result instead of throwing", async () => {
    const { api, fetchFn } = makeApi({});
    fetchFn.mockRejectedValue(new TypeError("network down"));

    expect(await api.listConsents()).toMatchObject({ ok: false, status: 0, code: "network_error" });
  });

  it("sends the device label on sign in", async () => {
    const { api, calls } = makeApi({ "POST /api/v1/sessions": jsonResponse(201, grant) }, null);

    await api.signIn("a@x.test", "uma-senha-longa");

    expect(JSON.parse(calls[0].init.body as string).device_label).toBe("Aparelho de teste");
  });

  it("navigates once and clears once when several requests get 401 together", async () => {
    const { api, session, onUnauthorized } = makeApi({
      "GET /api/v1/profile": errorResponse(401, "unauthorized"),
      "GET /api/v1/sport_profiles": errorResponse(401, "unauthorized"),
      "GET /api/v1/consents": errorResponse(401, "unauthorized"),
      "GET /api/v1/sessions": errorResponse(401, "unauthorized"),
    });

    await Promise.all([api.getProfile(), api.listSportProfiles(), api.listConsents(), api.listSessions()]);

    expect(session.clear).toHaveBeenCalledTimes(1);
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });

  it("ignores a late 401 from an old token and keeps the newly stored one", async () => {
    const ctx = makeApi({
      "GET /api/v1/profile": async () => {
        await ctx.session.setToken("token-novo");
        return errorResponse(401, "unauthorized");
      },
    });

    await ctx.api.getProfile();

    expect(ctx.session.clear).not.toHaveBeenCalled();
    expect(ctx.onUnauthorized).not.toHaveBeenCalled();
    expect(await ctx.session.getToken()).toBe("token-novo");
  });
});
