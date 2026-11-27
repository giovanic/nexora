import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { WATER_ID, goal, goalList } from "../../../shared/testing/goalFakes";
import { NewGoalScreen } from "../NewGoalScreen";

const ALL = ["log_meals", "include_fruits_vegetables", "drink_water", "sleep_routine", "planned_workout"];

describe("NewGoalScreen", () => {
  it("offers only types not already live", async () => {
    const ctx = makeApi({
      "GET /api/v1/goal_types": jsonResponse(200, { goal_types: ALL }),
      "GET /api/v1/goals": jsonResponse(200, goalList([goal(), goal({ id: WATER_ID, goal_type: "drink_water", status: "paused" })])),
    });
    await render(<NewGoalScreen api={ctx.api} onCreated={jest.fn()} />);

    expect(await screen.findByRole("button", { name: "Incluir frutas ou vegetais" })).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Dormir no horário que escolhi" })).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Fazer o treino planejado" })).toBeOnTheScreen();
    expect(screen.queryByText("Registrar as refeições do dia")).toBeNull();
    expect(screen.queryByText("Beber água ao longo do dia")).toBeNull();
  });

  it("ignores unknown type codes", async () => {
    const ctx = makeApi({
      "GET /api/v1/goal_types": jsonResponse(200, { goal_types: ["drink_water", "lose_weight", "calorie_target"] }),
      "GET /api/v1/goals": jsonResponse(200, goalList([])),
    });
    await render(<NewGoalScreen api={ctx.api} onCreated={jest.fn()} />);

    expect(await screen.findByRole("button", { name: "Beber água ao longo do dia" })).toBeOnTheScreen();
    expect(screen.getAllByRole("button")).toHaveLength(1);
    expect(screen.queryByText(/lose_weight|calorie/)).toBeNull();
  });

  it("creating returns to today", async () => {
    const ctx = makeApi({
      "GET /api/v1/goal_types": jsonResponse(200, { goal_types: ALL }),
      "GET /api/v1/goals": jsonResponse(200, goalList([])),
      "POST /api/v1/goals": jsonResponse(201, goal({ id: WATER_ID, goal_type: "drink_water" })),
    });
    const onCreated = jest.fn();
    await render(<NewGoalScreen api={ctx.api} onCreated={onCreated} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Beber água ao longo do dia" }));

    await waitFor(() => expect(onCreated).toHaveBeenCalledTimes(1));
    const call = ctx.calls.find((item) => item.key === "POST /api/v1/goals");
    expect(JSON.parse(call?.init.body as string)).toEqual({ goal_type: "drink_water" });
  });

  it("stays on the screen with a message when creating is refused", async () => {
    const ctx = makeApi({
      "GET /api/v1/goal_types": jsonResponse(200, { goal_types: ALL }),
      "GET /api/v1/goals": jsonResponse(200, goalList([])),
      "POST /api/v1/goals": jsonResponse(422, { error: { code: "validation_failed", message: "x", request_id: "r", details: [{ field: "goal_type", code: "unsupported_goal_type" }] } }),
    });
    const onCreated = jest.fn();
    await render(<NewGoalScreen api={ctx.api} onCreated={onCreated} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Beber água ao longo do dia" }));

    expect(await screen.findByText("Esse tipo de meta não está disponível.")).toBeOnTheScreen();
    expect(onCreated).not.toHaveBeenCalled();
  });

  it("shows an error with retry when the types do not load", async () => {
    const ctx = makeApi({ "GET /api/v1/goal_types": errorResponse(500, "internal_error"), "GET /api/v1/goals": jsonResponse(200, goalList([])) });
    await render(<NewGoalScreen api={ctx.api} onCreated={jest.fn()} />);

    expect(await screen.findByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });
});
