import { render, screen } from "@testing-library/react-native";
import { ApiStatusScreen } from "../ApiStatusScreen";

const allOk = { status: "ok", checks: { database: "ok", queue: "ok" } };

function okFetch() {
  return jest.fn(async () => ({ status: 200, json: async () => allOk })) as unknown as (
    url: string,
  ) => Promise<Response>;
}

describe("ApiStatusScreen", () => {
  it("shows the result of the check", async () => {
    await render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={okFetch()} showErrorTrigger={false} />);

    expect(await screen.findByText("API pronta")).toBeOnTheScreen();
  });

  it("shows the error state when the API cannot be reached", async () => {
    const fetchFn = jest.fn(async () => {
      throw new TypeError("network down");
    });

    await render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={fetchFn} showErrorTrigger={false} />);

    expect(await screen.findByText("Não foi possível falar com a API")).toBeOnTheScreen();
  });

  it("hides the test error trigger when disabled", async () => {
    await render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={okFetch()} showErrorTrigger={false} />);
    await screen.findByText("API pronta");

    expect(screen.queryByRole("button", { name: "Provocar erro de teste" })).toBeNull();
  });

  it("offers the test error trigger when enabled", async () => {
    await render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={okFetch()} showErrorTrigger />);
    await screen.findByText("API pronta");

    expect(screen.getByRole("button", { name: "Provocar erro de teste" })).toBeOnTheScreen();
  });
});
