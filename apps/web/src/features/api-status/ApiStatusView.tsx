import type { Checks } from "./fetchReadiness";
import type { ApiStatusState } from "./useApiStatus";

const DEPENDENCY_NAMES: Record<keyof Checks, string> = {
  database: "banco de dados",
  queue: "fila",
};

function failingDependencies(checks: Checks): string {
  return (Object.keys(DEPENDENCY_NAMES) as (keyof Checks)[])
    .filter((dependency) => checks[dependency] === "error")
    .map((dependency) => DEPENDENCY_NAMES[dependency])
    .join(", ");
}

function message(state: ApiStatusState): string {
  if (state === "loading") return "Verificando a API…";

  switch (state.kind) {
    case "ready":
      return "API pronta";
    case "degraded":
      return `API com problema: ${failingDependencies(state.checks)}`;
    case "unreachable":
      return "Não foi possível falar com a API";
  }
}

export function ApiStatusView({ state }: { state: ApiStatusState }) {
  return <p role="status">{message(state)}</p>;
}
