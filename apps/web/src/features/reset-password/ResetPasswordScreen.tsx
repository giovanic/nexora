import { useEffect, useState, type FormEvent } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { ErrorMessage } from "../../shared/ui";

const TOKEN_IN_FRAGMENT = /^#token=([A-Za-z0-9_-]+)$/;

// The token travels in the fragment, so it never reaches a server log or a Referer header.
// It is read once and removed from the address bar at once. Call it before rendering, not in a
// component: a second call (StrictMode runs effects twice) would find the fragment gone.
export function takeResetToken(): string | null {
  const token = TOKEN_IN_FRAGMENT.exec(window.location.hash)?.[1] ?? null;
  if (window.location.hash) history.replaceState(null, "", window.location.pathname + window.location.search);
  return token;
}

const INVALID_LINK = "Este link é inválido ou vencido. Peça outro no aplicativo.";
const PASSWORD_RULE = "A senha precisa ter pelo menos 12 caracteres. Escolha outra.";

export function ResetPasswordScreen({ api, token }: { api: Api; token: string | null }) {
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(token ? null : INVALID_LINK);
  const [done, setDone] = useState(false);

  useEffect(() => {
    const meta = document.createElement("meta");
    meta.name = "referrer";
    meta.content = "no-referrer";
    document.head.appendChild(meta);
    return () => meta.remove();
  }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!token) return;
    setBusy(true);
    setError(null);
    const result = await api.resetPassword(token, password);
    setBusy(false);
    setPassword("");
    if (result.ok) {
      setDone(true);
    } else if (result.code === "invalid_token") {
      setError(INVALID_LINK);
    } else if (result.code === "validation_failed") {
      setError(PASSWORD_RULE);
    } else {
      setError(errorMessage(result));
    }
  }

  if (done) {
    return (
      <main>
        <h1>Redefinir senha</h1>
        <p role="status">Senha alterada. Entre no aplicativo com a nova senha.</p>
      </main>
    );
  }

  return (
    <main>
      <h1>Redefinir senha</h1>
      {error && <ErrorMessage>{error}</ErrorMessage>}
      {token && (
        <form onSubmit={submit} aria-busy={busy}>
          <p>
            <label htmlFor="new-password">Nova senha</label>
            <input
              id="new-password"
              type="password"
              autoComplete="new-password"
              required
              aria-describedby="new-password-hint"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </p>
          <p id="new-password-hint">Use pelo menos 12 caracteres.</p>
          <button type="submit" disabled={busy}>
            {busy ? "Salvando…" : "Salvar nova senha"}
          </button>
        </form>
      )}
    </main>
  );
}
