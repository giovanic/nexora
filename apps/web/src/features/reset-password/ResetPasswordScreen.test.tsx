import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createApi } from "../../shared/api";
import { errorBody, fakeFetch } from "../../shared/testing";
import { ResetPasswordScreen, takeResetToken } from "./ResetPasswordScreen";

afterEach(() => history.replaceState(null, "", "/"));

describe("takeResetToken", () => {
  it("reset page reads the token from the fragment and clears it from the address", () => {
    history.replaceState(null, "", "/reset-password#token=abc_DEF-123");

    expect(takeResetToken()).toBe("abc_DEF-123");

    expect(window.location.hash).toBe("");
    expect(window.location.href).not.toContain("abc_DEF-123");
    expect(window.location.pathname).toBe("/reset-password");
  });

  it("returns null without a token", () => {
    history.replaceState(null, "", "/reset-password");
    expect(takeResetToken()).toBeNull();
  });
});

function setup(routes: Parameters<typeof fakeFetch>[0], token: string | null = "tok-1") {
  const fetchFn = fakeFetch(routes);
  const api = createApi({ baseUrl: "", fetchFn });
  render(<ResetPasswordScreen api={api} token={token} />);
  return fetchFn;
}

function submit(password = "a brand new password") {
  fireEvent.change(screen.getByLabelText("Nova senha"), { target: { value: password } });
  fireEvent.click(screen.getByRole("button", { name: "Salvar nova senha" }));
}

describe("ResetPasswordScreen", () => {
  it("asks the browser not to send a referrer while the page is open", () => {
    const { unmount } = render(<ResetPasswordScreen api={createApi({ baseUrl: "", fetchFn: fakeFetch({}) })} token="t" />);
    expect(document.head.querySelector('meta[name="referrer"]')?.getAttribute("content")).toBe("no-referrer");
    unmount();
    expect(document.head.querySelector('meta[name="referrer"]')).toBeNull();
  });

  it("sends the new password with the token and confirms", async () => {
    const fetchFn = setup({ "PATCH /api/v1/password_resets/tok-1": { status: 204 } });

    submit();

    await screen.findByText(/Senha alterada/);
    const init = fetchFn.mock.calls[0][1] as RequestInit;
    expect(JSON.parse(init.body as string)).toEqual({ password: "a brand new password" });
    expect(screen.queryByLabelText("Nova senha")).toBeNull();
  });

  it("explains an invalid or expired link", async () => {
    setup({ "PATCH /api/v1/password_resets/tok-1": { status: 422, body: errorBody("invalid_token") } });
    submit();
    expect((await screen.findByRole("alert")).textContent).toContain("inválido ou vencido");
  });

  it("explains the password rule and keeps the form", async () => {
    setup({ "PATCH /api/v1/password_resets/tok-1": { status: 422, body: errorBody("validation_failed") } });
    submit("short");
    expect((await screen.findByRole("alert")).textContent).toContain("12 caracteres");
    expect(screen.getByLabelText("Nova senha")).toBeTruthy();
  });

  it("shows the invalid link state when there is no token, without calling the API", () => {
    const fetchFn = setup({}, null);
    expect(screen.getByRole("alert").textContent).toContain("inválido ou vencido");
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("asks to try again later on a rate limit", async () => {
    setup({ "PATCH /api/v1/password_resets/tok-1": { status: 429, body: errorBody("rate_limited") } });
    submit();
    expect((await screen.findByRole("alert")).textContent).toContain("alguns minutos");
  });

  it("never prints the token or the password", async () => {
    const spies = (["log", "info", "warn", "error"] as const).map((m) => vi.spyOn(console, m));
    setup({ "PATCH /api/v1/password_resets/tok-1": { status: 204 } });
    submit();
    await waitFor(() => screen.getByText(/Senha alterada/));
    expect(document.body.textContent).not.toContain("tok-1");
    spies.forEach((s) => expect(s).not.toHaveBeenCalled());
    spies.forEach((s) => s.mockRestore());
  });
});
