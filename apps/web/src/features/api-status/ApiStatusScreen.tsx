import { ApiStatusView } from "./ApiStatusView";
import type { FetchFn } from "./fetchReadiness";
import { useApiStatus } from "./useApiStatus";

type Props = {
  baseUrl: string;
  fetchFn?: FetchFn;
  showErrorTrigger: boolean;
};

export function ApiStatusScreen({ baseUrl, fetchFn, showErrorTrigger }: Props) {
  const state = useApiStatus(baseUrl, fetchFn);

  return (
    <main>
      <h1>Estado da API</h1>
      <ApiStatusView state={state} />
      {showErrorTrigger && (
        <button
          type="button"
          onClick={() => {
            throw new Error("provoked web error");
          }}
        >
          Provocar erro de teste
        </button>
      )}
    </main>
  );
}
