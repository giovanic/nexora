import { render, screen } from "@testing-library/react";
import { fireEvent } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
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

  it("no token reaches localStorage or sessionStorage", async () => {
    localStorage.clear();
    sessionStorage.clear();
    let signedIn = false;
    const fetchFn = fakeFetch({
      "GET /api/v1/consents": () => (signedIn ? { body: { consents: [] } } : { status: 401, body: errorBody("unauthorized") }),
      "POST /api/v1/sessions": () => {
        signedIn = true;
        return { status: 201, body: { user_id: "u", expires_at: "x", token: "SECRET-TOKEN" } };
      },
    });
    render(<App fetchFn={fetchFn} />);
    fireEvent.change(await screen.findByLabelText("E-mail"), { target: { value: "ana@example.com" } });
    fireEvent.change(screen.getByLabelText("Senha"), { target: { value: "a long password" } });
    fireEvent.click(screen.getByRole("button", { name: "Entrar" }));
    await screen.findByRole("heading", { name: "Privacidade" });
    await screen.findByText("Nenhum consentimento para mostrar.");

    expect(localStorage.length).toBe(0);
    expect(sessionStorage.length).toBe(0);
    expect(document.cookie).toBe("");
    expect(document.body.textContent).not.toContain("SECRET-TOKEN");
  });

  it("shows the reset page on /reset-password", async () => {
    history.replaceState(null, "", "/reset-password");
    render(<App resetToken="t" fetchFn={fakeFetch({})} />);
    await screen.findByLabelText("Nova senha");
  });
});
