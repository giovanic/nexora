import { useState, type FormEvent } from "react";
import type { Api } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { ErrorMessage } from "../../shared/ui";

export function SignInForm({ api, onSignedIn }: { api: Api; onSignedIn: () => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    const result = await api.signIn(email, password);
    setBusy(false);
    if (result.ok) {
      setPassword("");
      onSignedIn();
    } else {
      setError(errorMessage(result));
    }
  }

  return (
    <main>
      <h1>Entrar</h1>
      <form onSubmit={submit} aria-busy={busy}>
        <p>
          <label htmlFor="signin-email">E-mail</label>
          <input id="signin-email" type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </p>
        <p>
          <label htmlFor="signin-password">Senha</label>
          <input id="signin-password" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </p>
        {error && <ErrorMessage>{error}</ErrorMessage>}
        <button type="submit" disabled={busy}>
          {busy ? "Entrando…" : "Entrar"}
        </button>
      </form>
      <p>A conta é criada pelo aplicativo.</p>
    </main>
  );
}
