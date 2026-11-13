import { useMemo, useState } from "react";
import { ApiStatusScreen } from "./features/api-status/ApiStatusScreen";
import { SignInForm } from "./features/auth/SignInForm";
import { PrivacyScreen } from "./features/privacy/PrivacyScreen";
import { ResetPasswordScreen } from "./features/reset-password/ResetPasswordScreen";
import { createApi, type FetchFn } from "./shared/api";

const API_URL = import.meta.env.VITE_API_URL ?? "http://localhost:3010";

type Props = {
  // Read from the fragment before rendering (see takeResetToken).
  resetToken?: string | null;
  fetchFn?: FetchFn;
};

// Three pages, picked by path: no router package needed.
export default function App({ resetToken = null, fetchFn }: Props) {
  const path = window.location.pathname;
  // "unknown" until the first call: a 401 on it means there is no session.
  const [session, setSession] = useState<"unknown" | "out">("unknown");
  // Same origin: in development the Vite proxy forwards /api, so the cookie stays first party.
  const api = useMemo(() => createApi({ baseUrl: "", fetchFn, onUnauthorized: () => setSession("out") }), [fetchFn]);

  if (path === "/reset-password") return <ResetPasswordScreen api={api} token={resetToken} />;
  if (path === "/status") return <ApiStatusScreen baseUrl={API_URL} showErrorTrigger={import.meta.env.DEV} />;

  if (session === "out") return <SignInForm api={api} onSignedIn={() => setSession("unknown")} />;
  return <PrivacyScreen api={api} onSignedOut={() => setSession("out")} />;
}
