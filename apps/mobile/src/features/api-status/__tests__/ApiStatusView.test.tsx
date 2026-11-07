import { render, screen } from "@testing-library/react-native";
import { ApiStatusView } from "../ApiStatusView";

describe("ApiStatusView", () => {
  it("shows the loading state", async () => {
    await render(<ApiStatusView state="loading" />);

    expect(screen.getByRole("status")).toHaveTextContent("Verificando a API…");
  });

  it("shows the ready state", async () => {
    await render(<ApiStatusView state={{ kind: "ready", checks: { database: "ok", queue: "ok" } }} />);

    expect(screen.getByRole("status")).toHaveTextContent("API pronta");
  });

  it("names the queue when it is the failing dependency", async () => {
    await render(<ApiStatusView state={{ kind: "degraded", checks: { database: "ok", queue: "error" } }} />);

    expect(screen.getByRole("status")).toHaveTextContent("API com problema: fila");
  });

  it("names the database when it is the failing dependency", async () => {
    await render(<ApiStatusView state={{ kind: "degraded", checks: { database: "error", queue: "ok" } }} />);

    expect(screen.getByRole("status")).toHaveTextContent("API com problema: banco de dados");
  });

  it("names both when both fail", async () => {
    await render(<ApiStatusView state={{ kind: "degraded", checks: { database: "error", queue: "error" } }} />);

    expect(screen.getByRole("status")).toHaveTextContent("API com problema: banco de dados, fila");
  });

  it("does not leave the failing dependency blank when no check failed", async () => {
    await render(<ApiStatusView state={{ kind: "degraded", checks: { database: "ok", queue: "ok" } }} />);

    expect(screen.getByRole("status")).toHaveTextContent(/^API com problema$/);
  });

  it("shows the unreachable state", async () => {
    await render(<ApiStatusView state={{ kind: "unreachable" }} />);

    expect(screen.getByRole("status")).toHaveTextContent("Não foi possível falar com a API");
  });
});
