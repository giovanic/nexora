import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ApiStatusView } from "./ApiStatusView";

describe("ApiStatusView", () => {
  it("shows the loading state", () => {
    render(<ApiStatusView state="loading" />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "Verificando a API…");
  });

  it("shows the ready state", () => {
    render(<ApiStatusView state={{ kind: "ready", checks: { database: "ok", queue: "ok" } }} />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "API pronta");
  });

  it("names the queue when it is the failing dependency", () => {
    render(<ApiStatusView state={{ kind: "degraded", checks: { database: "ok", queue: "error" } }} />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "API com problema: fila");
  });

  it("names the database when it is the failing dependency", () => {
    render(<ApiStatusView state={{ kind: "degraded", checks: { database: "error", queue: "ok" } }} />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "API com problema: banco de dados");
  });

  it("names both when both fail", () => {
    render(<ApiStatusView state={{ kind: "degraded", checks: { database: "error", queue: "error" } }} />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "API com problema: banco de dados, fila");
  });

  it("does not leave the failing dependency blank when no check failed", () => {
    render(<ApiStatusView state={{ kind: "degraded", checks: { database: "ok", queue: "ok" } }} />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "API com problema");
  });

  it("shows the unreachable state", () => {
    render(<ApiStatusView state={{ kind: "unreachable" }} />);

    expect(screen.getByRole("status")).toHaveProperty("textContent", "Não foi possível falar com a API");
  });
});
