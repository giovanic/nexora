import type { components } from "@app/contracts";

type HealthReady = components["schemas"]["HealthReady"];
export type Checks = HealthReady["checks"];

export type ReadinessResult =
  | { kind: "ready"; checks: Checks }
  | { kind: "degraded"; checks: Checks }
  | { kind: "unreachable" };

export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

const DEFAULT_TIMEOUT_MS = 5000;

const CHECK_VALUES: readonly unknown[] = ["ok", "error"];

function isHealthReady(body: unknown): body is HealthReady {
  if (typeof body !== "object" || body === null) return false;

  const { status, checks } = body as { status?: unknown; checks?: { database?: unknown; queue?: unknown } };

  return (
    (status === "ok" || status === "unavailable") &&
    CHECK_VALUES.includes(checks?.database) &&
    CHECK_VALUES.includes(checks?.queue)
  );
}

export async function fetchReadiness(
  baseUrl: string | undefined,
  fetchFn: FetchFn = fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
): Promise<ReadinessResult> {
  if (!baseUrl) return { kind: "unreachable" };

  const controller = new AbortController();
  let timer: ReturnType<typeof setTimeout> | undefined;
  // Raced as well as aborted, so a request that ignores the signal cannot hang the screen.
  const timedOut = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      controller.abort();
      reject(new Error("timed out"));
    }, timeoutMs);
  });

  try {
    const response = await Promise.race([fetchFn(`${baseUrl}/health/ready`, { signal: controller.signal }), timedOut]);
    const body: unknown = await Promise.race([response.json(), timedOut]);

    if (!isHealthReady(body)) return { kind: "unreachable" };
    if (response.status === 200 && body.status === "ok") return { kind: "ready", checks: body.checks };
    if (response.status === 503) return { kind: "degraded", checks: body.checks };

    return { kind: "unreachable" };
  } catch {
    return { kind: "unreachable" };
  } finally {
    clearTimeout(timer);
  }
}
