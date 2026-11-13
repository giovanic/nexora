import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { createApi } from "../../shared/api";
import { errorBody, fakeFetch } from "../../shared/testing";
import { SignInForm } from "./SignInForm";

function setup(routes: Parameters<typeof fakeFetch>[0]) {
  const onSignedIn = vi.fn();
  const api = createApi({ baseUrl: "", fetchFn: fakeFetch(routes) });
  render(<SignInForm api={api} onSignedIn={onSignedIn} />);
  return onSignedIn;
}

function submit() {
  fireEvent.change(screen.getByLabelText("E-mail"), { target: { value: "ana@example.com" } });
  fireEvent.change(screen.getByLabelText("Senha"), { target: { value: "a long password" } });
  fireEvent.click(screen.getByRole("button", { name: "Entrar" }));
}

describe("SignInForm", () => {
  it("signs in and tells the app", async () => {
    const onSignedIn = setup({ "POST /api/v1/sessions": { status: 201, body: { user_id: "u", expires_at: "x" } } });
    submit();
    await vi.waitFor(() => expect(onSignedIn).toHaveBeenCalled());
  });

  it("shows a neutral message for wrong credentials and moves focus to it", async () => {
    const onSignedIn = setup({ "POST /api/v1/sessions": { status: 401, body: errorBody("invalid_credentials") } });
    submit();
    const alert = await screen.findByRole("alert");
    expect(alert.textContent).toBe("E-mail ou senha incorretos.");
    // ErrorMessage moves focus in an effect, which can run after findByRole resolves.
    await waitFor(() => expect(document.activeElement).toBe(alert));
    expect(onSignedIn).not.toHaveBeenCalled();
  });

  it("asks to wait on a rate limit", async () => {
    setup({ "POST /api/v1/sessions": { status: 429, body: errorBody("rate_limited") } });
    submit();
    expect((await screen.findByRole("alert")).textContent).toContain("alguns minutos");
  });

  it("disables the button and announces progress while sending", async () => {
    let release: () => void = () => {};
    const gate = new Promise<void>((r) => (release = r));
    const fetchFn = vi.fn(async () => {
      await gate;
      return new Response(JSON.stringify({ user_id: "u", expires_at: "x" }), { status: 201 });
    });
    const onSignedIn = vi.fn();
    render(<SignInForm api={createApi({ baseUrl: "", fetchFn })} onSignedIn={onSignedIn} />);
    submit();
    expect((screen.getByRole("button", { name: "Entrando…" }) as HTMLButtonElement).disabled).toBe(true);
    release();
    await vi.waitFor(() => expect(onSignedIn).toHaveBeenCalled());
  });
});
