import { fetchReadiness } from "../fetchReadiness";

const allOk = { status: "ok", checks: { database: "ok", queue: "ok" } };
const queueDown = { status: "unavailable", checks: { database: "ok", queue: "error" } };

function respondWith(status: number, body: string) {
  return jest.fn(async () => ({
    status,
    json: async () => JSON.parse(body),
  })) as unknown as (url: string, init?: RequestInit) => Promise<Response>;
}

describe("fetchReadiness", () => {
  it("requests the readiness route of the given base URL", async () => {
    const fetchFn = respondWith(200, JSON.stringify(allOk));

    await fetchReadiness("http://api.test", fetchFn);

    expect(fetchFn).toHaveBeenCalledWith("http://api.test/health/ready", expect.objectContaining({ signal: expect.any(AbortSignal) }));
  });

  it("returns ready for a valid 200", async () => {
    expect(await fetchReadiness("http://api.test", respondWith(200, JSON.stringify(allOk)))).toEqual({
      kind: "ready",
      checks: allOk.checks,
    });
  });

  it("returns degraded with the checks for a valid 503", async () => {
    expect(await fetchReadiness("http://api.test", respondWith(503, JSON.stringify(queueDown)))).toEqual({
      kind: "degraded",
      checks: queueDown.checks,
    });
  });

  it("returns unreachable for an HTML error page from a proxy", async () => {
    expect(await fetchReadiness("http://api.test", respondWith(502, "<html>Bad Gateway</html>"))).toEqual({
      kind: "unreachable",
    });
  });

  it("returns unreachable for JSON in another format", async () => {
    expect(await fetchReadiness("http://api.test", respondWith(200, JSON.stringify({ hello: "world" })))).toEqual({
      kind: "unreachable",
    });
  });

  it("returns unreachable when a check has an unknown value", async () => {
    const body = JSON.stringify({ status: "ok", checks: { database: "maybe", queue: "ok" } });

    expect(await fetchReadiness("http://api.test", respondWith(200, body))).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable for a central error", async () => {
    const body = JSON.stringify({ error: { code: "internal_error", message: "x", request_id: "1" } });

    expect(await fetchReadiness("http://api.test", respondWith(500, body))).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable when the API never answers", async () => {
    const fetchFn = jest.fn(() => new Promise<Response>(() => {}));

    expect(await fetchReadiness("http://api.test", fetchFn, 10)).toEqual({ kind: "unreachable" });
  });

  it("aborts the request when the API never answers", async () => {
    let signal: AbortSignal | null | undefined;
    const fetchFn = jest.fn((_url: string, init?: RequestInit) => {
      signal = init?.signal;
      return new Promise<Response>(() => {});
    });

    await fetchReadiness("http://api.test", fetchFn, 10);

    expect(signal?.aborted).toBe(true);
  });

  it("returns unreachable when the network fails", async () => {
    const fetchFn = jest.fn(async () => {
      throw new TypeError("network down");
    });

    expect(await fetchReadiness("http://api.test", fetchFn)).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable without a base URL, and does not call the network", async () => {
    const fetchFn = jest.fn();

    expect(await fetchReadiness(undefined, fetchFn)).toEqual({ kind: "unreachable" });
    expect(fetchFn).not.toHaveBeenCalled();
  });
});
