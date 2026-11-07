import type { components } from "@app/contracts";

type HealthReady = components["schemas"]["HealthReady"];
export type Checks = HealthReady["checks"];

export type ReadinessResult =
  | { kind: "ready"; checks: Checks }
  | { kind: "degraded"; checks: Checks }
  | { kind: "unreachable" };

export type FetchFn = (url: string) => Promise<Response>;

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

export async function fetchReadiness(baseUrl: string | undefined, fetchFn: FetchFn = fetch): Promise<ReadinessResult> {
  if (!baseUrl) return { kind: "unreachable" };

  try {
    const response = await fetchFn(`${baseUrl}/health/ready`);
    const body: unknown = await response.json();

    if (!isHealthReady(body)) return { kind: "unreachable" };
    if (response.status === 200 && body.status === "ok") return { kind: "ready", checks: body.checks };
    if (response.status === 503) return { kind: "degraded", checks: body.checks };

    return { kind: "unreachable" };
  } catch {
    return { kind: "unreachable" };
  }
}
