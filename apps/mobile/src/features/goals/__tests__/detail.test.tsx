import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { MEALS_ID, TODAY, YESTERDAY, goal, goalList } from "../../../shared/testing/goalFakes";
import { GoalDetailScreen } from "../GoalDetailScreen";

const LIST = "GET /api/v1/goals";
const PATCH = `PATCH /api/v1/goals/${MEALS_ID}`;
const DELETE = `DELETE /api/v1/goals/${MEALS_ID}`;
const HISTORY = `GET /api/v1/goals/history?goal_id=${MEALS_ID}`;
const day = (local_date: string, sources = ["manual"]) => ({ goal_id: MEALS_ID, goal_type: "log_meals", goal_status: "active", local_date, sources });
const page = (items: unknown[], next_cursor: string | null = null) => jsonResponse(200, { items, next_cursor });
const props = () => ({ goalId: MEALS_ID, onDeleted: jest.fn() });

describe("GoalDetailScreen", () => {
  it("pauses and resumes", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal()])),
      [HISTORY]: page([]),
      [PATCH]: (init: RequestInit) => jsonResponse(200, goal({ status: JSON.parse(init.body as string).status })),
    });
    await render(<GoalDetailScreen api={ctx.api} {...props()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Pausar" }));
    expect(await screen.findByText("Pausada. Retome quando quiser.")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Retomar" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "Pausar" })).toBeOnTheScreen());
    expect(ctx.calls.filter((item) => item.key === PATCH).map((item) => JSON.parse(item.init.body as string))).toEqual([{ status: "paused" }, { status: "active" }]);
  });

  it("ending asks for confirmation", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])), [HISTORY]: page([]), [PATCH]: jsonResponse(200, goal({ status: "ended", ends_on: TODAY })) });
    await render(<GoalDetailScreen api={ctx.api} {...props()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Encerrar" }));
    expect(screen.getByText("Encerrar esta meta? O histórico continua disponível.")).toBeOnTheScreen();
    expect(ctx.calls.some((item) => item.key === PATCH)).toBe(false);

    await fireEvent.press(screen.getByRole("button", { name: "Cancelar" }));
    expect(screen.queryByText("Encerrar esta meta? O histórico continua disponível.")).toBeNull();

    await fireEvent.press(screen.getByRole("button", { name: "Encerrar" }));
    await fireEvent.press(screen.getByRole("button", { name: "Sim, encerrar" }));

    await waitFor(() => expect(ctx.calls.filter((item) => item.key === PATCH)).toHaveLength(1));
    expect(JSON.parse(ctx.calls.find((item) => item.key === PATCH)?.init.body as string)).toEqual({ status: "ended" });
    expect(await screen.findByText("Meta encerrada.")).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Pausar" })).toBeNull();
  });

  it("deleting asks for confirmation and leaves the screen", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])), [HISTORY]: page([]), [DELETE]: jsonResponse(204) });
    const handlers = props();
    await render(<GoalDetailScreen api={ctx.api} {...handlers} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Apagar" }));
    expect(screen.getByText("Apagar esta meta e o histórico dela? Isso não pode ser desfeito.")).toBeOnTheScreen();
    expect(ctx.calls.some((item) => item.key === DELETE)).toBe(false);
    expect(handlers.onDeleted).not.toHaveBeenCalled();

    await fireEvent.press(screen.getByRole("button", { name: "Sim, apagar" }));

    await waitFor(() => expect(handlers.onDeleted).toHaveBeenCalledTimes(1));
    expect(ctx.calls.filter((item) => item.key === DELETE)).toHaveLength(1);
  });

  it("history loads more pages", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal()])),
      [HISTORY]: page([day(TODAY), day(YESTERDAY, ["food_entry"])], "c1"),
      [`${HISTORY}&cursor=c1`]: page([day("2026-11-20")]),
    });
    await render(<GoalDetailScreen api={ctx.api} {...props()} />);

    expect(await screen.findByText("26/11/2026")).toBeOnTheScreen();
    expect(screen.getByText("25/11/2026 · pela refeição registrada")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Carregar mais" }));

    expect(await screen.findByText("20/11/2026")).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Carregar mais" })).toBeNull();
  });

  it("history empty state", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])), [HISTORY]: page([]) });
    await render(<GoalDetailScreen api={ctx.api} {...props()} />);

    expect(await screen.findByText("Os dias marcados aparecem aqui.")).toBeOnTheScreen();
  });

  it("shows an error with retry when the history does not load", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])), [HISTORY]: errorResponse(500, "internal_error"), [PATCH]: errorResponse(409, "goal_not_active") });
    await render(<GoalDetailScreen api={ctx.api} {...props()} />);

    expect(await screen.findByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });

  it("after ending, the history stays visible with only delete", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal()])),
      [HISTORY]: page([day(TODAY)]),
      [PATCH]: jsonResponse(200, goal({ status: "ended", ends_on: TODAY })),
    });
    await render(<GoalDetailScreen api={ctx.api} {...props()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Encerrar" }));
    await fireEvent.press(screen.getByRole("button", { name: "Sim, encerrar" }));

    expect(await screen.findByText("Meta encerrada.")).toBeOnTheScreen();
    expect(screen.getByText("26/11/2026")).toBeOnTheScreen();
    expect(screen.queryByText(/Não encontramos esta meta/)).toBeNull();
    for (const name of ["Pausar", "Retomar", "Encerrar"]) expect(screen.queryByRole("button", { name })).toBeNull();
    expect(screen.getByRole("button", { name: "Apagar" })).toBeOnTheScreen();
  });
});
