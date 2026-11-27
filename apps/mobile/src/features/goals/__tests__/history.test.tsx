import { fireEvent, render, screen } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { MEALS_ID, TODAY, WATER_ID, YESTERDAY } from "../../../shared/testing/goalFakes";
import { GoalHistoryScreen } from "../GoalHistoryScreen";

const HISTORY = "GET /api/v1/goals/history";
const day = (goal_id: string, goal_type: string, local_date: string, goal_status = "active", sources = ["manual"]) => ({ goal_id, goal_type, goal_status, local_date, sources });
const page = (items: unknown[], next_cursor: string | null = null) => jsonResponse(200, { items, next_cursor });

describe("GoalHistoryScreen", () => {
  it("lists completed days of all goals, ended ones marked", async () => {
    const ctx = makeApi({ [HISTORY]: page([day(MEALS_ID, "log_meals", TODAY), day(WATER_ID, "drink_water", YESTERDAY, "ended")]) });
    await render(<GoalHistoryScreen api={ctx.api} />);

    expect(await screen.findByText("Registrar as refeições do dia · 26/11/2026")).toBeOnTheScreen();
    expect(screen.getByText("Beber água ao longo do dia · 25/11/2026 · Encerrada")).toBeOnTheScreen();
    expect(screen.getAllByText(/Encerrada/)).toHaveLength(1);
  });

  it("loads more pages", async () => {
    const ctx = makeApi({
      [HISTORY]: page([day(MEALS_ID, "log_meals", TODAY)], "c1"),
      [`${HISTORY}?cursor=c1`]: page([day(MEALS_ID, "log_meals", "2026-11-20")]),
    });
    await render(<GoalHistoryScreen api={ctx.api} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Carregar mais" }));

    expect(await screen.findByText("Registrar as refeições do dia · 20/11/2026")).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Carregar mais" })).toBeNull();
  });

  it("empty state", async () => {
    const ctx = makeApi({ [HISTORY]: page([]) });
    await render(<GoalHistoryScreen api={ctx.api} />);

    expect(await screen.findByText("Os dias marcados aparecem aqui.")).toBeOnTheScreen();
  });

  it("ignores unknown type codes", async () => {
    const ctx = makeApi({ [HISTORY]: page([day(MEALS_ID, "calorie_target", TODAY), day(WATER_ID, "drink_water", TODAY)]) });
    await render(<GoalHistoryScreen api={ctx.api} />);

    expect(await screen.findByText("Beber água ao longo do dia · 26/11/2026")).toBeOnTheScreen();
    expect(screen.queryByText(/calorie/)).toBeNull();
  });

  it("shows an error with retry", async () => {
    const ctx = makeApi({ [HISTORY]: errorResponse(500, "internal_error") });
    await render(<GoalHistoryScreen api={ctx.api} />);

    expect(await screen.findByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });
});
