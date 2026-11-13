import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { consentList, errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { SettingsScreen } from "../SettingsScreen";

const profile = { display_name: "Ana", time_zone: "America/Sao_Paulo", units: "metric", motivations: ["start_caring"] };
const sport = { id: "11111111-1111-4111-8111-111111111111", sport: "running", level: "beginner", started_at: "2026-11-01T00:00:00Z" };
const sessions = {
  sessions: [
    { id: "s-current", client: "mobile", device_label: "Este celular", created_at: "2026-11-01T12:00:00Z", last_used_at: "2026-11-13T12:00:00Z", current: true },
    { id: "s-other", client: "mobile", device_label: "Tablet antigo", created_at: "2026-11-01T00:00:00Z", last_used_at: "2026-11-10T12:00:00Z", current: false },
  ],
};

function baseRoutes() {
  return {
    "GET /api/v1/profile": jsonResponse(200, profile),
    "GET /api/v1/sport_profiles": jsonResponse(200, { sport_profiles: [sport] }),
    "GET /api/v1/consents": consentList({ health_data: "granted" }),
    "GET /api/v1/sessions": jsonResponse(200, sessions),
  };
}

function setup(routes: Record<string, never> | Record<string, unknown> = {}, props: { webUrl?: string; openUrl?: (url: string) => void } = {}) {
  const ctx = makeApi({ ...baseRoutes(), ...routes } as never);
  const handlers = { onSignedOut: jest.fn(), onOpenConsent: jest.fn(), onHealthRevoked: jest.fn() };
  const element = <SettingsScreen api={ctx.api} {...handlers} {...props} />;
  return { ...ctx, ...handlers, element };
}

const HEALTH_WARNING =
  "Ao retirar este consentimento, apagamos seus esportes, níveis, motivações e nome de exibição. Sua conta continua, e você volta à tela de consentimento.";

describe("SettingsScreen sections", () => {
  it("shows the profile, sports, consents and sessions", async () => {
    const { element } = setup();
    await render(element);

    expect(await screen.findByDisplayValue("Ana")).toBeOnTheScreen();
    expect(screen.getByRole("checkbox", { name: "Começar a me cuidar", checked: true })).toBeOnTheScreen();
    expect(screen.getByRole("radio", { name: "Corrida: Iniciante", checked: true })).toBeOnTheScreen();
    expect(screen.getByText("Dados de saúde")).toBeOnTheScreen();
    expect(screen.getByText("Tablet antigo")).toBeOnTheScreen();
    expect(screen.getByText("Este aparelho")).toBeOnTheScreen();
  });

  it("tells sessions apart by device, kind and last use", async () => {
    const { element } = setup();
    await render(element);

    expect(await screen.findByText("Aplicativo no celular · último uso em 10/11/2026")).toBeOnTheScreen();
    expect(screen.getByText("Aplicativo no celular · último uso em 13/11/2026")).toBeOnTheScreen();
  });

  it("shows loading in every section", async () => {
    const never = () => new Promise<never>(() => {});
    const ctx = makeApi({ "GET /api/v1/profile": never, "GET /api/v1/sport_profiles": never, "GET /api/v1/consents": never, "GET /api/v1/sessions": never } as never, "t");
    const timers = jest.useFakeTimers();
    await render(<SettingsScreen api={ctx.api} onSignedOut={jest.fn()} onOpenConsent={jest.fn()} onHealthRevoked={jest.fn()} />);

    expect(screen.getAllByText("Carregando…")).toHaveLength(4);
    timers.clearAllTimers();
    jest.useRealTimers();
  });

  it("shows an error with retry in each section that fails", async () => {
    const { element } = setup({
      "GET /api/v1/profile": errorResponse(500, "internal_error"),
      "GET /api/v1/sport_profiles": errorResponse(500, "internal_error"),
      "GET /api/v1/consents": errorResponse(500, "internal_error"),
      "GET /api/v1/sessions": errorResponse(500, "internal_error"),
    });
    await render(element);

    expect(await screen.findAllByRole("button", { name: "Tentar de novo" })).toHaveLength(4);
  });

  it("shows the empty state for sports", async () => {
    const { element } = setup({ "GET /api/v1/sport_profiles": jsonResponse(200, { sport_profiles: [] }) });
    await render(element);

    expect(await screen.findByText("Você ainda não escolheu nenhum esporte.")).toBeOnTheScreen();
  });

  it("without health_data the person can open Settings, delete the account and see the consents", async () => {
    const { element, onOpenConsent, calls, onSignedOut } = setup({
      "GET /api/v1/profile": errorResponse(403, "consent_required"),
      "GET /api/v1/sport_profiles": errorResponse(403, "consent_required"),
      "GET /api/v1/consents": consentList({ health_data: "revoked" }),
      "DELETE /api/v1/account": jsonResponse(202),
    });
    await render(element);

    const notices = await screen.findAllByText(/Esta parte depende do consentimento de dados de saúde/);
    expect(notices).toHaveLength(2);
    expect(onOpenConsent).not.toHaveBeenCalled();
    expect(screen.getByText("Dados de saúde")).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Ver texto: Dados de saúde" })).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Sair" })).toBeOnTheScreen();
    expect(screen.getByText("Para exportar seus dados, use o painel web.")).toBeOnTheScreen();

    await fireEvent.press(screen.getAllByRole("button", { name: "Dar consentimento de dados de saúde" })[0]);
    expect(onOpenConsent).toHaveBeenCalledTimes(1);

    await fireEvent.press(screen.getByRole("button", { name: "Excluir conta" }));
    await fireEvent.changeText(screen.getByLabelText("Senha para confirmar"), "uma-senha-bem-longa");
    await fireEvent.press(screen.getByRole("button", { name: "Excluir minha conta" }));
    await waitFor(() => expect(onSignedOut).toHaveBeenCalledTimes(1));
    expect(calls.some((c) => c.key === "DELETE /api/v1/account")).toBe(true);
  });

  it("saves the profile", async () => {
    const { element, calls } = setup({ "PATCH /api/v1/profile": jsonResponse(200, profile) });
    await render(element);
    await fireEvent.changeText(await screen.findByLabelText("Nome de exibição"), "Ana C.");

    await fireEvent.press(screen.getByRole("button", { name: "Salvar perfil" }));

    expect(await screen.findByText("Perfil salvo.")).toBeOnTheScreen();
    expect(JSON.parse(calls.find((c) => c.key === "PATCH /api/v1/profile")!.init.body as string)).toEqual({
      display_name: "Ana C.",
      motivations: ["start_caring"],
    });
  });

  it("changes the level of a sport and stops a sport", async () => {
    const { element, calls } = setup({
      "POST /api/v1/sport_profiles": jsonResponse(201, sport),
      [`DELETE /api/v1/sport_profiles/${sport.id}`]: jsonResponse(204),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("radio", { name: "Corrida: Avançado" }));
    await waitFor(() => expect(calls.some((c) => c.key === "POST /api/v1/sport_profiles")).toBe(true));
    expect(JSON.parse(calls.find((c) => c.key === "POST /api/v1/sport_profiles")!.init.body as string)).toEqual({ sport: "running", level: "advanced" });

    await fireEvent.press(await screen.findByRole("button", { name: "Parar: Corrida" }));
    await waitFor(() => expect(calls.some((c) => c.key.startsWith("DELETE /api/v1/sport_profiles/"))).toBe(true));
  });

  it("revokes another device and keeps this one without a button", async () => {
    const { element, calls } = setup({ "DELETE /api/v1/sessions/s-other": jsonResponse(204) });
    await render(element);

    expect(await screen.findByText("Tablet antigo")).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Encerrar sessão: Este celular" })).toBeNull();
    await fireEvent.press(screen.getByRole("button", { name: "Encerrar sessão: Tablet antigo" }));

    await waitFor(() => expect(calls.some((c) => c.key === "DELETE /api/v1/sessions/s-other")).toBe(true));
  });
});

describe("consents in settings", () => {
  it("confirms exactly what happens before revoking health_data, then returns to the consent step", async () => {
    const { element, calls, onHealthRevoked } = setup({ "DELETE /api/v1/consents/health_data": jsonResponse(204) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Retirar: Dados de saúde" }));

    expect(screen.getByText(HEALTH_WARNING)).toBeOnTheScreen();
    expect(calls.some((c) => c.key.startsWith("DELETE /api/v1/consents"))).toBe(false);

    await fireEvent.press(screen.getByRole("button", { name: "Confirmar retirada" }));

    await waitFor(() => expect(onHealthRevoked).toHaveBeenCalledTimes(1));
    expect(calls.some((c) => c.key === "DELETE /api/v1/consents/health_data")).toBe(true);
  });

  it("does nothing when the person cancels the confirmation", async () => {
    const { element, calls, onHealthRevoked } = setup();
    await render(element);
    await fireEvent.press(await screen.findByRole("button", { name: "Retirar: Dados de saúde" }));

    await fireEvent.press(screen.getByRole("button", { name: "Cancelar" }));

    expect(screen.queryByText(HEALTH_WARNING)).toBeNull();
    expect(onHealthRevoked).not.toHaveBeenCalled();
    expect(calls.some((c) => c.key.startsWith("DELETE /api/v1/consents"))).toBe(false);
  });

  it("shows the text before granting another purpose", async () => {
    const { element, calls } = setup({
      "GET /api/v1/consents/food_photo_ai/text": jsonResponse(200, { purpose: "food_photo_ai", version: 3, text: "Texto da foto com IA." }),
      "POST /api/v1/consents": jsonResponse(201, {}),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Ver texto: Foto da refeição analisada por IA" }));
    expect(await screen.findByText("Texto da foto com IA.")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Conceder: Foto da refeição analisada por IA" }));

    await waitFor(() => expect(calls.some((c) => c.key === "POST /api/v1/consents")).toBe(true));
    expect(JSON.parse(calls.find((c) => c.key === "POST /api/v1/consents")!.init.body as string)).toEqual({ purpose: "food_photo_ai", version: 3 });
  });
});

describe("consent wording", () => {
  it("uses the shared state labels", async () => {
    const { element } = setup({ "GET /api/v1/consents": consentList({ health_data: "granted", food_photo_ai: "outdated", strava_integration: "revoked" }) });
    await render(element);

    expect(await screen.findByText("Texto novo: leia e conceda de novo")).toBeOnTheScreen();
    expect(screen.getByText("Ainda não respondido")).toBeOnTheScreen();
    expect(screen.getByText("Retirado")).toBeOnTheScreen();
    expect(screen.getByText("Concedido")).toBeOnTheScreen();
  });

  it("explains why the text changed when the version is outdated", async () => {
    const { element } = setup({
      "GET /api/v1/consents/food_photo_ai/text": jsonResponse(200, { purpose: "food_photo_ai", version: 4, text: "Texto novo." }),
      "POST /api/v1/consents": errorResponse(409, "outdated_version"),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Ver texto: Foto da refeição analisada por IA" }));
    await fireEvent.press(await screen.findByRole("button", { name: "Conceder: Foto da refeição analisada por IA" }));

    expect(await screen.findByText("O texto deste consentimento foi atualizado. Leia a versão atual antes de aceitar.")).toBeOnTheScreen();
    expect(screen.getByText("Texto novo.")).toBeOnTheScreen();
  });
});

describe("account", () => {
  it("delete account asks for the password", async () => {
    const { element, calls, onSignedOut } = setup({ "DELETE /api/v1/account": jsonResponse(202) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Excluir conta" }));
    await fireEvent.press(screen.getByRole("button", { name: "Excluir minha conta" }));

    expect(await screen.findByText("Digite a sua senha para excluir a conta.")).toBeOnTheScreen();
    expect(calls.some((c) => c.key === "DELETE /api/v1/account")).toBe(false);

    await fireEvent.changeText(screen.getByLabelText("Senha para confirmar"), "uma-senha-bem-longa");
    await fireEvent.press(screen.getByRole("button", { name: "Excluir minha conta" }));

    await waitFor(() => expect(onSignedOut).toHaveBeenCalledTimes(1));
    expect(JSON.parse(calls.find((c) => c.key === "DELETE /api/v1/account")!.init.body as string)).toEqual({ password: "uma-senha-bem-longa" });
  });

  it("keeps the session and says the password is wrong", async () => {
    const { element, session, onSignedOut, onUnauthorized } = setup({ "DELETE /api/v1/account": errorResponse(401, "invalid_credentials") });
    await render(element);
    await fireEvent.press(await screen.findByRole("button", { name: "Excluir conta" }));
    await fireEvent.changeText(screen.getByLabelText("Senha para confirmar"), "errada");

    await fireEvent.press(screen.getByRole("button", { name: "Excluir minha conta" }));

    expect(await screen.findByText("Senha incorreta. Nada foi excluído.")).toBeOnTheScreen();
    expect(session.clear).not.toHaveBeenCalled();
    expect(onUnauthorized).not.toHaveBeenCalled();
    expect(onSignedOut).not.toHaveBeenCalled();
  });

  it("shows a calm message on a rate limit", async () => {
    const { element } = setup({ "DELETE /api/v1/account": errorResponse(429, "too_many_requests", { "Retry-After": "600" }) });
    await render(element);
    await fireEvent.press(await screen.findByRole("button", { name: "Excluir conta" }));
    await fireEvent.changeText(screen.getByLabelText("Senha para confirmar"), "qualquer-senha");

    await fireEvent.press(screen.getByRole("button", { name: "Excluir minha conta" }));

    expect(await screen.findByText("Muitas tentativas. Tente novamente em alguns minutos.")).toBeOnTheScreen();
  });

  it("signs out of this device", async () => {
    const { element, calls, onSignedOut, session } = setup({ "DELETE /api/v1/sessions/current": jsonResponse(204) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Sair" }));

    await waitFor(() => expect(onSignedOut).toHaveBeenCalledTimes(1));
    expect(calls.some((c) => c.key === "DELETE /api/v1/sessions/current")).toBe(true);
    expect(session.clear).toHaveBeenCalled();
  });

  it("explains that export happens on the web, with a link when the web URL is set", async () => {
    const openUrl = jest.fn();
    const { element } = setup({}, { webUrl: "https://app.exemplo.test", openUrl });
    await render(element);

    expect(await screen.findByText("Para exportar seus dados, use o painel web.")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("link", { name: "Abrir o painel web" }));

    expect(openUrl).toHaveBeenCalledWith("https://app.exemplo.test");
  });

  it("shows only the text when there is no web URL", async () => {
    const { element } = setup();
    await render(element);

    expect(await screen.findByText("Para exportar seus dados, use o painel web.")).toBeOnTheScreen();
    expect(screen.queryByRole("link", { name: "Abrir o painel web" })).toBeNull();
  });
});
