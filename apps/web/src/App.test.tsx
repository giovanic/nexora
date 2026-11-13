import { render, screen } from "@testing-library/react";
import { afterEach, describe, it } from "vitest";
import App from "./App";
import { errorBody, fakeFetch } from "./shared/testing";

afterEach(() => history.replaceState(null, "", "/"));

describe("App", () => {
  it("shows sign in when there is no session", async () => {
    render(<App fetchFn={fakeFetch({ "GET /api/v1/consents": { status: 401, body: errorBody("unauthorized") } })} />);
    await screen.findByRole("button", { name: "Entrar" });
  });

  it("shows the privacy page when the cookie session is valid", async () => {
    render(<App fetchFn={fakeFetch({ "GET /api/v1/consents": { body: { consents: [] } } })} />);
    await screen.findByRole("heading", { name: "Privacidade" });
  });

  it("shows the reset page on /reset-password", async () => {
    history.replaceState(null, "", "/reset-password");
    render(<App resetToken="t" fetchFn={fakeFetch({})} />);
    await screen.findByLabelText("Nova senha");
  });
});
