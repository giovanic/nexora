import { describe, expect, it, vi } from "vitest";
import { fetchReadiness } from "./fetchReadiness";

const allOk = { status: "ok", checks: { database: "ok", queue: "ok" } };
const queueDown = { status: "unavailable", checks: { database: "ok", queue: "error" } };

function respondWith(status: number, body: string, contentType = "application/json") {
  return vi.fn(async () => new Response(body, { status, headers: { "content-type": contentType } }));
}

describe("fetchReadiness", () => {
  it("requests the readiness route of the given base URL", async () => {
    const fetchFn = respondWith(200, JSON.stringify(allOk));

    await fetchReadiness("http://api.test", fetchFn);

    expect(fetchFn).toHaveBeenCalledWith("http://api.test/health/ready", expect.objectContaining({ signal: expect.any(AbortSignal) }));
  });

  it("returns ready for a valid 200", async () => {
    const result = await fetchReadiness("http://api.test", respondWith(200, JSON.stringify(allOk)));

    expect(result).toEqual({ kind: "ready", checks: allOk.checks });
  });

  it("returns degraded with the checks for a valid 503", async () => {
    const result = await fetchReadiness("http://api.test", respondWith(503, JSON.stringify(queueDown)));

    expect(result).toEqual({ kind: "degraded", checks: queueDown.checks });
  });

  it("returns unreachable for an HTML error page from a proxy", async () => {
    const result = await fetchReadiness("http://api.test", respondWith(502, "<html>Bad Gateway</html>", "text/html"));

    expect(result).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable for a 200 with HTML", async () => {
    const result = await fetchReadiness("http://api.test", respondWith(200, "<html></html>", "text/html"));

    expect(result).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable for JSON in another format", async () => {
    const result = await fetchReadiness("http://api.test", respondWith(200, JSON.stringify({ hello: "world" })));

    expect(result).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable when a check has an unknown value", async () => {
    const body = JSON.stringify({ status: "ok", checks: { database: "maybe", queue: "ok" } });

    const result = await fetchReadiness("http://api.test", respondWith(200, body));

    expect(result).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable for a central error", async () => {
    const body = JSON.stringify({ error: { code: "internal_error", message: "x", request_id: "1" } });

    const result = await fetchReadiness("http://api.test", respondWith(500, body));

    expect(result).toEqual({ kind: "unreachable" });
  });

  it("returns unreachable when the API never answers", async () => {
    const fetchFn = vi.fn(() => new Promise<Response>(() => {}));

    expect(await fetchReadiness("http://api.test", fetchFn, 10)).toEqual({ kind: "unreachable" });
  });

  it("aborts the request when the API never answers", async () => {
    let signal: AbortSignal | undefined;
    const fetchFn = vi.fn((_url: string, init?: RequestInit) => {
      signal = init?.signal ?? undefined;
      return new Promise<Response>(() => {});
    });

    await fetchReadiness("http://api.test", fetchFn, 10);

    expect(signal?.aborted).toBe(true);
  });

  it("returns unreachable when the network fails", async () => {
    const fetchFn = vi.fn(async () => {
      throw new TypeError("network down");
    });

    const result = await fetchReadiness("http://api.test", fetchFn);

    expect(result).toEqual({ kind: "unreachable" });
  });
});
