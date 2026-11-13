import { useState, type FormEvent } from "react";
import type { Failure } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { ErrorMessage } from "../../shared/ui";

type Props = {
  id: string;
  title: string;
  description: string;
  passwordLabel: string;
  submitLabel: string;
  busyLabel: string;
  // Resolves to null on success, or the failure to explain.
  run: (password: string) => Promise<Failure | null>;
  success?: string;
  wrongPassword?: string;
};

// A section that asks for the password again before a sensitive action.
export function PasswordAction({ id, title, description, passwordLabel, submitLabel, busyLabel, run, success, wrongPassword = "A senha não confere." }: Props) {
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);
    setDone(false);
    const failure = await run(password);
    setBusy(false);
    setPassword("");
    if (!failure) setDone(true);
    else setError(failure.code === "invalid_credentials" ? wrongPassword : errorMessage(failure));
  }

  return (
    <section aria-labelledby={`${id}-title`}>
      <h2 id={`${id}-title`}>{title}</h2>
      <p>{description}</p>
      <form onSubmit={submit} aria-busy={busy}>
        <p>
          <label htmlFor={`${id}-password`}>{passwordLabel}</label>
          <input id={`${id}-password`} type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </p>
        {error && <ErrorMessage>{error}</ErrorMessage>}
        <button type="submit" disabled={busy}>
          {busy ? busyLabel : submitLabel}
        </button>
      </form>
      <div aria-live="polite">{done && success}</div>
    </section>
  );
}
