import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import { initMonitoring } from "./shared/monitoring";

initMonitoring(import.meta.env.VITE_ERROR_TRACKING_DSN);

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
