import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import { takeResetToken } from "./features/reset-password/ResetPasswordScreen";
import { initMonitoring } from "./shared/monitoring";

initMonitoring(import.meta.env.VITE_ERROR_TRACKING_DSN);

// Before the first render, so the token leaves the address bar at once.
const resetToken = window.location.pathname === "/reset-password" ? takeResetToken() : null;

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App resetToken={resetToken} />
  </StrictMode>,
);
