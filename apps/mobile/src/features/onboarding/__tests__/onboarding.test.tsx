import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { consentList, errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { ComingSoonScreen } from "../ComingSoonScreen";
import { ConsentStep } from "../ConsentStep";
import { DoneStep } from "../DoneStep";
import { MotivationsStep } from "../MotivationsStep";
import { ResumeGate } from "../ResumeGate";
import { SportsStep } from "../SportsStep";

const text = jsonResponse(200, { purpose: "health_data", version: 2, text: "Usamos seus dados de saúde para personalizar o app." });

describe("ResumeGate", () => {
  it.each(["pending", "revoked", "outdated"])("onboarding resumes at consent when health_data is %s", async (state) => {
    const { api } = makeApi({ "GET /api/v1/consents": consentList({ health_data: state }) });
    const onRoute = jest.fn();

    await render(<ResumeGate api={api} onRoute={onRoute} />);

    await waitFor(() => expect(onRoute).toHaveBeenCalledWith("/onboarding/consent"));
  });

  it("goes to the app when health_data is granted", async () => {
    const { api } = makeApi({ "GET /api/v1/consents": consentList({ health_data: "granted" }) });
    const onRoute = jest.fn();

    await render(<ResumeGate api={api} onRoute={onRoute} />);

    await waitFor(() => expect(onRoute).toHaveBeenCalledWith("/home"));
  });

  it("shows the loading state while the consents are fetched", async () => {
    let release: () => void = () => {};
    const slow = new Promise<ReturnType<typeof consentList>>((resolve) => {
      release = () => resolve(consentList({ health_data: "granted" }));
    });
    const { api } = makeApi({ "GET /api/v1/consents": () => slow });
    const onRoute = jest.fn();

    await render(<ResumeGate api={api} onRoute={onRoute} />);
    expect(screen.getByText("Carregando…")).toBeOnTheScreen();

    release();
    await waitFor(() => expect(onRoute).toHaveBeenCalled());
  });

  it("shows an error with retry", async () => {
    const answers = [errorResponse(500, "internal_error"), consentList({ health_data: "granted" })];
    const { api } = makeApi({ "GET /api/v1/consents": () => answers.shift()! });
    const onRoute = jest.fn();

    await render(<ResumeGate api={api} onRoute={onRoute} />);

    expect(await screen.findByText("Algo deu errado do nosso lado. Tente de novo em instantes.")).toBeOnTheScreen();
    expect(onRoute).not.toHaveBeenCalled();

    await fireEvent.press(screen.getByRole("button", { name: "Tentar de novo" }));
    await waitFor(() => expect(onRoute).toHaveBeenCalledWith("/home"));
  });
});

describe("ConsentStep", () => {
  it("shows the server text and grants the current version", async () => {
    const { api, calls } = makeApi({ "GET /api/v1/consents/health_data/text": text, "POST /api/v1/consents": jsonResponse(201, {}) });
    const onGranted = jest.fn();
    await render(<ConsentStep api={api} onGranted={onGranted} onSignOut={jest.fn()} onOpenSettings={jest.fn()} />);

    expect(await screen.findByText("Usamos seus dados de saúde para personalizar o app.")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Concordo e continuar" }));

    await screen.findByRole("button", { name: "Concordo e continuar" });
    expect(JSON.parse(calls.find((c) => c.key === "POST /api/v1/consents")!.init.body as string)).toEqual({ purpose: "health_data", version: 2 });
    expect(onGranted).toHaveBeenCalledTimes(1);
  });

  it("says calmly that the withdrawal is still being applied, and lets the person try again later", async () => {
    const { api, fetchFn } = makeApi({
      "GET /api/v1/consents/health_data/text": text,
      "POST /api/v1/consents": errorResponse(409, "revocation_pending"),
    });
    const onGranted = jest.fn();
    await render(<ConsentStep api={api} onGranted={onGranted} onSignOut={jest.fn()} onOpenSettings={jest.fn()} />);
    await screen.findByText(/Usamos seus dados/);

    await fireEvent.press(screen.getByRole("button", { name: "Concordo e continuar" }));

    expect(await screen.findByText(/ainda está sendo aplicada. Tente de novo mais tarde/)).toBeOnTheScreen();
    expect(onGranted).not.toHaveBeenCalled();
    expect(fetchFn.mock.calls.filter(([url]) => String(url).endsWith("/consents"))).toHaveLength(1);
    expect(screen.getByRole("button", { name: "Concordo e continuar" })).toBeOnTheScreen();
  });

  it("shows the error state when the text cannot be loaded", async () => {
    const { api } = makeApi({ "GET /api/v1/consents/health_data/text": errorResponse(500, "internal_error") });
    await render(<ConsentStep api={api} onGranted={jest.fn()} onSignOut={jest.fn()} onOpenSettings={jest.fn()} />);

    expect(await screen.findByText(/Algo deu errado do nosso lado/)).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });

  it("offers to leave without agreeing", async () => {
    const { api } = makeApi({ "GET /api/v1/consents/health_data/text": text });
    const onSignOut = jest.fn();
    await render(<ConsentStep api={api} onGranted={jest.fn()} onSignOut={onSignOut} onOpenSettings={jest.fn()} />);
    await screen.findByText(/Usamos seus dados/);

    await fireEvent.press(screen.getByRole("link", { name: "Sair da conta" }));

    expect(onSignOut).toHaveBeenCalledTimes(1);
  });
});

describe("ConsentStep without agreeing", () => {
  it("links to settings, to delete the account or manage other consents", async () => {
    const { api } = makeApi({ "GET /api/v1/consents/health_data/text": text });
    const onOpenSettings = jest.fn();
    await render(<ConsentStep api={api} onGranted={jest.fn()} onSignOut={jest.fn()} onOpenSettings={onOpenSettings} />);
    await screen.findByText(/Usamos seus dados/);

    await fireEvent.press(screen.getByRole("link", { name: "Configurações, para excluir a conta ou ver outras opções" }));

    expect(onOpenSettings).toHaveBeenCalledTimes(1);
  });
});

describe("MotivationsStep", () => {
  it("skip works on motivations", async () => {
    const { api, fetchFn } = makeApi({});
    const onNext = jest.fn();
    await render(<MotivationsStep api={api} onNext={onNext} onConsentRequired={jest.fn()} />);

    await fireEvent.press(screen.getByRole("button", { name: "Pular" }));

    expect(onNext).toHaveBeenCalledTimes(1);
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("saves the chosen motivations", async () => {
    const { api, calls } = makeApi({ "PATCH /api/v1/profile": jsonResponse(200, {}) });
    const onNext = jest.fn();
    await render(<MotivationsStep api={api} onNext={onNext} onConsentRequired={jest.fn()} />);

    await fireEvent.press(screen.getByRole("checkbox", { name: "Ter constância nos treinos" }));
    await fireEvent.press(screen.getByRole("checkbox", { name: "Entender minha alimentação" }));
    await fireEvent.press(screen.getByRole("button", { name: "Continuar" }));

    await screen.findByRole("button", { name: "Continuar" });
    expect(JSON.parse(calls[0].init.body as string)).toEqual({ motivations: ["training_consistency", "understand_food"] });
    expect(onNext).toHaveBeenCalledTimes(1);
  });

  it("goes back to the consent step on 403 consent_required", async () => {
    const { api } = makeApi({ "PATCH /api/v1/profile": errorResponse(403, "consent_required") });
    const onConsentRequired = jest.fn();
    await render(<MotivationsStep api={api} onNext={jest.fn()} onConsentRequired={onConsentRequired} />);
    await fireEvent.press(screen.getByRole("checkbox", { name: "Começar a me cuidar" }));

    await fireEvent.press(screen.getByRole("button", { name: "Continuar" }));

    await screen.findByRole("button", { name: "Continuar" });
    expect(onConsentRequired).toHaveBeenCalledTimes(1);
  });

  it("shows an error and keeps the choices when saving fails", async () => {
    const { api } = makeApi({ "PATCH /api/v1/profile": errorResponse(500, "internal_error") });
    const onNext = jest.fn();
    await render(<MotivationsStep api={api} onNext={onNext} onConsentRequired={jest.fn()} />);
    await fireEvent.press(screen.getByRole("checkbox", { name: "Começar a me cuidar" }));

    await fireEvent.press(screen.getByRole("button", { name: "Continuar" }));

    expect(await screen.findByText(/Algo deu errado do nosso lado/)).toBeOnTheScreen();
    expect(onNext).not.toHaveBeenCalled();
    expect(screen.getByRole("checkbox", { name: "Começar a me cuidar", checked: true })).toBeOnTheScreen();
  });
});

describe("SportsStep", () => {
  it("skip works on sports", async () => {
    const { api, fetchFn } = makeApi({});
    const onNext = jest.fn();
    await render(<SportsStep api={api} onNext={onNext} onConsentRequired={jest.fn()} />);

    await fireEvent.press(screen.getByRole("button", { name: "Pular" }));

    expect(onNext).toHaveBeenCalledTimes(1);
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("saves each chosen sport with its level", async () => {
    const { api, calls } = makeApi({ "POST /api/v1/sport_profiles": jsonResponse(201, {}) });
    const onNext = jest.fn();
    await render(<SportsStep api={api} onNext={onNext} onConsentRequired={jest.fn()} />);

    await fireEvent.press(screen.getByRole("checkbox", { name: "Corrida" }));
    await fireEvent.press(screen.getByRole("radio", { name: "Corrida: Avançado" }));
    await fireEvent.press(screen.getByRole("checkbox", { name: "Natação" }));
    await fireEvent.press(screen.getByRole("button", { name: "Continuar" }));

    await screen.findByRole("button", { name: "Continuar" });
    expect(calls.map((c) => JSON.parse(c.init.body as string))).toEqual([
      { sport: "running", level: "advanced" },
      { sport: "swimming", level: "beginner" },
    ]);
    expect(onNext).toHaveBeenCalledTimes(1);
  });

  it("shows an error and stays when saving fails", async () => {
    const { api } = makeApi({ "POST /api/v1/sport_profiles": errorResponse(500, "internal_error") });
    const onNext = jest.fn();
    await render(<SportsStep api={api} onNext={onNext} onConsentRequired={jest.fn()} />);
    await fireEvent.press(screen.getByRole("checkbox", { name: "Corrida" }));

    await fireEvent.press(screen.getByRole("button", { name: "Continuar" }));

    expect(await screen.findByText(/Algo deu errado do nosso lado/)).toBeOnTheScreen();
    expect(onNext).not.toHaveBeenCalled();
  });
});

describe("DoneStep and ComingSoonScreen", () => {
  it("opens the camera step, which is coming soon", async () => {
    const onOpenCamera = jest.fn();
    await render(<DoneStep onOpenCamera={onOpenCamera} />);

    expect(screen.getByRole("heading", { name: "Pronto" })).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Abrir a câmera" }));

    expect(onOpenCamera).toHaveBeenCalledTimes(1);
  });

  it("says the camera is coming soon and links to settings", async () => {
    const onOpenSettings = jest.fn();
    await render(<ComingSoonScreen onOpenSettings={onOpenSettings} />);

    expect(screen.getByRole("heading", { name: "Em breve" })).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Configurações" }));

    expect(onOpenSettings).toHaveBeenCalledTimes(1);
  });
});
