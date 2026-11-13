import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { createApi } from "../../shared/api";
import { errorBody, fakeFetch } from "../../shared/testing";
import { PrivacyScreen } from "./PrivacyScreen";

const consent = (purpose: string, state: string, extra = {}) => ({
  purpose,
  state,
  current_version: 2,
  accepted_version: state === "granted" ? 2 : null,
  decided_at: null,
  ...extra,
});

const list = {
  consents: [consent("health_data", "granted"), consent("food_photo_ai", "pending"), consent("strava_integration", "revoked"), consent("usage_metrics", "outdated", { accepted_version: 1 })],
};

function setup(routes: Parameters<typeof fakeFetch>[0], extra: { download?: (name: string, content: string) => void } = {}) {
  const fetchFn = fakeFetch({ "GET /api/v1/consents": { body: list }, ...routes });
  const onSignedOut = vi.fn();
  const onUnauthorized = vi.fn();
  const api = createApi({ baseUrl: "", fetchFn, onUnauthorized });
  render(<PrivacyScreen api={api} onSignedOut={onSignedOut} download={extra.download ?? vi.fn()} />);
  return { fetchFn, onSignedOut, onUnauthorized };
}

const row = async (name: string) => within(await screen.findByRole("listitem", { name }));

describe("PrivacyScreen consents", () => {
  it("shows loading, then every purpose with its state", async () => {
    setup({});
    expect(screen.getByRole("status").textContent).toContain("Carregando");
    const health = await row("Dados de saúde");
    expect(health.getByText("Concedido")).toBeTruthy();
    expect((await row("Fotos de refeição para a IA")).getByText("Pendente")).toBeTruthy();
    expect((await row("Integração com o Strava")).getByText("Retirado")).toBeTruthy();
    expect((await row("Métricas de uso")).getByText("Texto atualizado")).toBeTruthy();
  });

  it("shows an error state with a retry", async () => {
    let calls = 0;
    setup({ "GET /api/v1/consents": () => (++calls === 1 ? { status: 500, body: errorBody("internal") } : { body: list }) });
    expect((await screen.findByRole("alert")).textContent).toContain("do nosso lado");
    fireEvent.click(screen.getByRole("button", { name: "Tentar de novo" }));
    await row("Dados de saúde");
  });

  it("shows the text of the current version and grants it", async () => {
    const { fetchFn } = setup({
      "GET /api/v1/consents/food_photo_ai/text": { body: { purpose: "food_photo_ai", version: 2, text: "Texto do consentimento" } },
      "POST /api/v1/consents": { status: 201, body: consent("food_photo_ai", "granted") },
    });
    fireEvent.click((await row("Fotos de refeição para a IA")).getByRole("button", { name: "Ler e conceder" }));
    await screen.findByText("Texto do consentimento");
    fireEvent.click(screen.getByRole("button", { name: "Aceitar a versão 2" }));
    await waitFor(() => expect(fetchFn.mock.calls.some(([u, i]) => (i as RequestInit)?.method === "POST" && u.endsWith("/consents"))).toBe(true));
    const post = fetchFn.mock.calls.find(([, i]) => (i as RequestInit)?.method === "POST")!;
    expect(JSON.parse((post[1] as RequestInit).body as string)).toEqual({ purpose: "food_photo_ai", version: 2 });
  });

  it("answers calmly to revocation_pending and does not retry by itself", async () => {
    const { fetchFn } = setup({
      "GET /api/v1/consents/strava_integration/text": { body: { purpose: "strava_integration", version: 2, text: "t" } },
      "POST /api/v1/consents": { status: 409, body: errorBody("revocation_pending") },
    });
    fireEvent.click((await row("Integração com o Strava")).getByRole("button", { name: "Ler e conceder" }));
    fireEvent.click(await screen.findByRole("button", { name: "Aceitar a versão 2" }));
    expect((await screen.findByRole("alert")).textContent).toContain("ainda está sendo aplicada");
    const posts = () => fetchFn.mock.calls.filter(([, i]) => (i as RequestInit)?.method === "POST").length;
    expect(posts()).toBe(1);
    await new Promise((r) => setTimeout(r, 50));
    expect(posts()).toBe(1);
  });

  it("confirms what is erased before revoking health_data", async () => {
    const { fetchFn } = setup({ "DELETE /api/v1/consents/health_data": { status: 204 } });
    fireEvent.click((await row("Dados de saúde")).getByRole("button", { name: "Retirar" }));
    const dialog = await screen.findByRole("group", { name: "Retirar o consentimento de dados de saúde" });
    expect(dialog.textContent).toContain("esportes, níveis, motivações e nome de exibição");
    expect(dialog.textContent).toContain("A conta continua");
    expect(fetchFn.mock.calls.some(([, i]) => (i as RequestInit)?.method === "DELETE")).toBe(false);
    fireEvent.click(within(dialog).getByRole("button", { name: "Confirmar a retirada" }));
    await waitFor(() => expect(fetchFn.mock.calls.some(([u, i]) => (i as RequestInit)?.method === "DELETE" && u.endsWith("/consents/health_data"))).toBe(true));
  });

  it("can cancel the revocation", async () => {
    const { fetchFn } = setup({});
    fireEvent.click((await row("Dados de saúde")).getByRole("button", { name: "Retirar" }));
    fireEvent.click(await screen.findByRole("button", { name: "Manter" }));
    expect(screen.queryByRole("group", { name: /Retirar o consentimento/ })).toBeNull();
    expect(fetchFn.mock.calls.some(([, i]) => (i as RequestInit)?.method === "DELETE")).toBe(false);
  });
});

describe("PrivacyScreen export", () => {
  it("export downloads JSON after the password", async () => {
    const download = vi.fn();
    const data = { identity: { email: "ana@example.com" } };
    const { fetchFn } = setup({ "POST /api/v1/account/export": { body: data } }, { download });
    await row("Dados de saúde");

    fireEvent.change(screen.getByLabelText("Senha para exportar"), { target: { value: "my password" } });
    fireEvent.click(screen.getByRole("button", { name: "Exportar meus dados" }));

    await waitFor(() => expect(download).toHaveBeenCalledTimes(1));
    expect(download.mock.calls[0][0]).toMatch(/\.json$/);
    expect(JSON.parse(download.mock.calls[0][1])).toEqual(data);
    const post = fetchFn.mock.calls.find(([u]) => u.endsWith("/account/export"))!;
    expect(JSON.parse((post[1] as RequestInit).body as string)).toEqual({ password: "my password" });
    expect(document.body.textContent).not.toContain("ana@example.com");
    expect((screen.getByLabelText("Senha para exportar") as HTMLInputElement).value).toBe("");
  });

  it("wrong password stays on the page with a neutral message and downloads nothing", async () => {
    const download = vi.fn();
    const { onUnauthorized } = setup({ "POST /api/v1/account/export": { status: 401, body: errorBody("invalid_credentials") } }, { download });
    await row("Dados de saúde");
    fireEvent.change(screen.getByLabelText("Senha para exportar"), { target: { value: "bad" } });
    fireEvent.click(screen.getByRole("button", { name: "Exportar meus dados" }));
    expect((await screen.findByText("A senha não confere.")).getAttribute("role")).toBe("alert");
    expect(download).not.toHaveBeenCalled();
    expect(onUnauthorized).not.toHaveBeenCalled();
  });

  it("asks to wait on the export limit", async () => {
    setup({ "POST /api/v1/account/export": { status: 429, body: errorBody("rate_limited") } });
    await row("Dados de saúde");
    fireEvent.change(screen.getByLabelText("Senha para exportar"), { target: { value: "x" } });
    fireEvent.click(screen.getByRole("button", { name: "Exportar meus dados" }));
    expect((await screen.findByRole("alert")).textContent).toContain("alguns minutos");
  });
});

describe("PrivacyScreen account", () => {
  it("deletes the account after the password and signs out of the page", async () => {
    const { fetchFn, onSignedOut } = setup({ "DELETE /api/v1/account": { status: 202 } });
    await row("Dados de saúde");
    fireEvent.change(screen.getByLabelText("Senha para excluir"), { target: { value: "my password" } });
    fireEvent.click(screen.getByRole("button", { name: "Excluir minha conta" }));
    await waitFor(() => expect(onSignedOut).toHaveBeenCalled());
    const call = fetchFn.mock.calls.find(([, i]) => (i as RequestInit)?.method === "DELETE")!;
    expect(JSON.parse((call[1] as RequestInit).body as string)).toEqual({ password: "my password" });
  });

  it("keeps the account on a wrong password", async () => {
    const { onSignedOut } = setup({ "DELETE /api/v1/account": { status: 401, body: errorBody("invalid_credentials") } });
    await row("Dados de saúde");
    fireEvent.change(screen.getByLabelText("Senha para excluir"), { target: { value: "bad" } });
    fireEvent.click(screen.getByRole("button", { name: "Excluir minha conta" }));
    expect((await screen.findByText("A senha não confere.")).getAttribute("role")).toBe("alert");
    expect(onSignedOut).not.toHaveBeenCalled();
  });

  it("signs out", async () => {
    const { onSignedOut } = setup({ "DELETE /api/v1/sessions/current": { status: 204 } });
    await row("Dados de saúde");
    fireEvent.click(screen.getByRole("button", { name: "Sair" }));
    await waitFor(() => expect(onSignedOut).toHaveBeenCalled());
  });
});
