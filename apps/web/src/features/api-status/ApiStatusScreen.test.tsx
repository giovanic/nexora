import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ApiStatusScreen } from "./ApiStatusScreen";

const allOk = { status: "ok", checks: { database: "ok", queue: "ok" } };

describe("ApiStatusScreen", () => {
  it("shows loading and then the result", async () => {
    const fetchFn = vi.fn(async () => new Response(JSON.stringify(allOk), { status: 200 }));

    render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={fetchFn} showErrorTrigger={false} />);

    expect(screen.getByRole("status").textContent).toBe("Verificando a API…");
    await screen.findByText("API pronta");
  });

  it("shows the error state when the API cannot be reached", async () => {
    const fetchFn = vi.fn(async () => {
      throw new TypeError("network down");
    });

    render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={fetchFn} showErrorTrigger={false} />);

    await screen.findByText("Não foi possível falar com a API");
  });

  it("offers the test error trigger only when enabled", async () => {
    const fetchFn = vi.fn(async () => new Response(JSON.stringify(allOk), { status: 200 }));

    const { unmount } = render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={fetchFn} showErrorTrigger={false} />);
    await screen.findByText("API pronta");
    expect(screen.queryByRole("button", { name: "Provocar erro de teste" })).toBeNull();
    unmount();

    render(<ApiStatusScreen baseUrl="http://api.test" fetchFn={fetchFn} showErrorTrigger />);
    await screen.findByText("API pronta");
    expect(screen.getByRole("button", { name: "Provocar erro de teste" })).toBeTruthy();
  });
});
