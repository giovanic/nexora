import { fireEvent, render, screen } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { ForgotPasswordScreen } from "../ForgotPasswordScreen";
import { SignInScreen } from "../SignInScreen";
import { SignUpScreen } from "../SignUpScreen";

const grant = { user_id: "u1", expires_at: "2026-12-01T00:00:00Z", token: "novo-token" };

async function fillSignUp(password = "uma-senha-bem-longa") {
  await fireEvent.changeText(screen.getByLabelText("E-mail"), "ana@exemplo.test");
  await fireEvent.changeText(screen.getByLabelText("Senha"), password);
}

describe("SignUpScreen", () => {
  function setup(routes = { "POST /api/v1/registrations": jsonResponse(201, grant) }, zone: string | null = "America/Sao_Paulo") {
    const ctx = makeApi(routes, null);
    const onSignedUp = jest.fn();
    return { ...ctx, onSignedUp, element: <SignUpScreen api={ctx.api} getTimeZone={() => zone} onSignedUp={onSignedUp} onGoToSignIn={jest.fn()} /> };
  }

  it("sign up requires the adult checkbox", async () => {
    const { element, fetchFn, onSignedUp } = setup();
    await render(element);
    await fillSignUp();

    await fireEvent.press(screen.getByRole("button", { name: "Criar conta" }));

    expect(await screen.findByText("Para criar a conta, confirme que você tem 18 anos ou mais.")).toBeOnTheScreen();
    expect(fetchFn).not.toHaveBeenCalled();
    expect(onSignedUp).not.toHaveBeenCalled();

    await fireEvent.press(screen.getByRole("checkbox", { name: "Tenho 18 anos ou mais" }));
    await fireEvent.press(screen.getByRole("button", { name: "Criar conta" }));

    await screen.findByRole("button", { name: "Criar conta" });
    expect(fetchFn).toHaveBeenCalledTimes(1);
    expect(onSignedUp).toHaveBeenCalledTimes(1);
  });

  it("shows a clear error when the device time zone is unavailable", async () => {
    const { element, fetchFn } = setup(undefined, null);
    await render(element);
    await fillSignUp();
    await fireEvent.press(screen.getByRole("checkbox", { name: "Tenho 18 anos ou mais" }));

    await fireEvent.press(screen.getByRole("button", { name: "Criar conta" }));

    expect(await screen.findByText(/fuso horário do aparelho/)).toBeOnTheScreen();
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("explains an e-mail that already has an account", async () => {
    const { element, onSignedUp } = setup({ "POST /api/v1/registrations": errorResponse(422, "email_taken") } as never);
    await render(element);
    await fillSignUp();
    await fireEvent.press(screen.getByRole("checkbox", { name: "Tenho 18 anos ou mais" }));

    await fireEvent.press(screen.getByRole("button", { name: "Criar conta" }));

    expect(await screen.findByText(/Já existe uma conta com este e-mail/)).toBeOnTheScreen();
    expect(onSignedUp).not.toHaveBeenCalled();
  });

  it("shows a calm message on a rate limit", async () => {
    const { element } = setup({ "POST /api/v1/registrations": errorResponse(429, "too_many_requests", { "Retry-After": "300" }) } as never);
    await render(element);
    await fillSignUp();
    await fireEvent.press(screen.getByRole("checkbox", { name: "Tenho 18 anos ou mais" }));

    await fireEvent.press(screen.getByRole("button", { name: "Criar conta" }));

    expect(await screen.findByText("Muitas tentativas. Tente novamente em alguns minutos.")).toBeOnTheScreen();
  });

  it("submits from the keyboard on the last field and labels every control", async () => {
    const { element, fetchFn } = setup();
    await render(element);
    await fillSignUp();
    await fireEvent.press(screen.getByRole("checkbox", { name: "Tenho 18 anos ou mais" }));

    await fireEvent(screen.getByLabelText("Senha"), "submitEditing");

    await screen.findByRole("button", { name: "Criar conta" });
    expect(fetchFn).toHaveBeenCalledTimes(1);
    expect(screen.getByRole("heading", { name: "Criar conta" })).toBeOnTheScreen();
    expect(screen.getByRole("link", { name: "Já tenho conta" })).toBeOnTheScreen();
  });
});

describe("SignInScreen", () => {
  function setup(route = jsonResponse(201, grant)) {
    const ctx = makeApi({ "POST /api/v1/sessions": route }, null);
    const onSignedIn = jest.fn();
    return { ...ctx, onSignedIn, element: <SignInScreen api={ctx.api} onSignedIn={onSignedIn} onGoToSignUp={jest.fn()} onGoToForgotPassword={jest.fn()} /> };
  }

  it("signs in and hands over to the app", async () => {
    const { element, onSignedIn, session } = setup();
    await render(element);
    await fireEvent.changeText(screen.getByLabelText("E-mail"), "ana@exemplo.test");
    await fireEvent.changeText(screen.getByLabelText("Senha"), "uma-senha-bem-longa");

    await fireEvent(screen.getByLabelText("Senha"), "submitEditing");

    await screen.findByRole("button", { name: "Entrar" });
    expect(onSignedIn).toHaveBeenCalledTimes(1);
    expect(session.setToken).toHaveBeenCalledWith("novo-token");
  });

  it("shows a neutral message on a wrong password and keeps the session untouched", async () => {
    const { element, onSignedIn, session } = setup(errorResponse(401, "invalid_credentials") as never);
    await render(element);
    await fireEvent.changeText(screen.getByLabelText("E-mail"), "ana@exemplo.test");
    await fireEvent.changeText(screen.getByLabelText("Senha"), "errada");

    await fireEvent.press(screen.getByRole("button", { name: "Entrar" }));

    expect(await screen.findByText("E-mail ou senha incorretos.")).toBeOnTheScreen();
    expect(onSignedIn).not.toHaveBeenCalled();
    expect(session.clear).not.toHaveBeenCalled();
  });

  it("asks for both fields before calling the API", async () => {
    const { element, fetchFn } = setup();
    await render(element);

    await fireEvent.press(screen.getByRole("button", { name: "Entrar" }));

    expect(await screen.findByText("Digite o e-mail e a senha.")).toBeOnTheScreen();
    expect(fetchFn).not.toHaveBeenCalled();
  });

  it("links to recovery and to sign up", async () => {
    const { element } = setup();
    await render(element);

    expect(screen.getByRole("link", { name: "Esqueci minha senha" })).toBeOnTheScreen();
    expect(screen.getByRole("link", { name: "Criar conta" })).toBeOnTheScreen();
  });
});

describe("ForgotPasswordScreen", () => {
  it("gives the same answer whether or not the e-mail has an account", async () => {
    const { api } = makeApi({ "POST /api/v1/password_resets": jsonResponse(202) }, null);
    await render(<ForgotPasswordScreen api={api} onBack={jest.fn()} />);
    await fireEvent.changeText(screen.getByLabelText("E-mail"), "ana@exemplo.test");

    await fireEvent.press(screen.getByRole("button", { name: "Enviar link" }));

    expect(await screen.findByText(/Se houver uma conta com este e-mail, enviamos um link/)).toBeOnTheScreen();
  });

  it("shows a calm message on a rate limit and on network failure", async () => {
    const { api } = makeApi({ "POST /api/v1/password_resets": errorResponse(429, "too_many_requests", { "Retry-After": "60" }) }, null);
    await render(<ForgotPasswordScreen api={api} onBack={jest.fn()} />);
    await fireEvent.changeText(screen.getByLabelText("E-mail"), "ana@exemplo.test");

    await fireEvent.press(screen.getByRole("button", { name: "Enviar link" }));

    expect(await screen.findByText("Muitas tentativas. Tente novamente em alguns minutos.")).toBeOnTheScreen();
  });
});
