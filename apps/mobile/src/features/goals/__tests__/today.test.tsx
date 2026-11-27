import { fireEvent, render, screen, waitFor, within } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { MEALS_ID, SLEEP_ID, TODAY, WATER_ID, YESTERDAY, goal, goalDay, goalList, outsideWindow } from "../../../shared/testing/goalFakes";
import { GoalsTodayScreen } from "../GoalsTodayScreen";

const LIST = "GET /api/v1/goals";
const CHECK = `POST /api/v1/goals/${MEALS_ID}/check_ins`;
const UNCHECK = (date: string) => `DELETE /api/v1/goals/${MEALS_ID}/check_ins/${date}`;
const handlers = () => ({ onNew: jest.fn(), onOpen: jest.fn(), onHistory: jest.fn() });

describe("GoalsTodayScreen", () => {
  it("shows today's goals and marks one done", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])), [CHECK]: jsonResponse(200, goalDay()) });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    expect(await screen.findByText("Registrar as refeições do dia")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Feito" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "Feito", selected: true })).toBeOnTheScreen());
    const call = ctx.calls.find((item) => item.key === CHECK);
    expect(JSON.parse(call?.init.body as string)).toEqual({ local_date: TODAY });
  });

  it("switches to yesterday using the dates from the API", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal({ done_yesterday: true })])),
      [CHECK]: jsonResponse(200, goalDay({ local_date: YESTERDAY })),
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await screen.findByText("Registrar as refeições do dia");
    expect(screen.getByRole("button", { name: "Feito", selected: false })).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("radio", { name: "Ontem" }));
    expect(screen.getByRole("button", { name: "Feito", selected: true })).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("radio", { name: "Hoje" }));
    expect(screen.getByRole("button", { name: "Feito", selected: false })).toBeOnTheScreen();

    await fireEvent.press(screen.getByRole("radio", { name: "Ontem" }));
    await fireEvent.press(screen.getByRole("button", { name: "Feito" }));
    await waitFor(() => expect(ctx.calls.some((item) => item.key === UNCHECK(YESTERDAY))).toBe(true));
  });

  it("tapping done again unchecks", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal()])),
      [CHECK]: jsonResponse(200, goalDay()),
      [UNCHECK(TODAY)]: jsonResponse(200, goalDay({ done: false, sources: [] })),
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Feito" }));
    await waitFor(() => expect(screen.getByRole("button", { name: "Feito", selected: true })).toBeOnTheScreen());
    await fireEvent.press(screen.getByRole("button", { name: "Feito" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "Feito", selected: false })).toBeOnTheScreen());
    expect(ctx.calls.filter((item) => item.key === UNCHECK(TODAY))).toHaveLength(1);
  });

  it("log_meals completed by a meal says so and stays done after unchecking", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal({ done_today: true })])),
      [UNCHECK(TODAY)]: jsonResponse(200, goalDay({ done: true, sources: ["food_entry"] })),
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Feito" }));

    expect(await screen.findByText("Cumprida pela refeição registrada.")).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Feito", selected: true })).toBeOnTheScreen();
  });

  it("keeps the previous state and offers retry when the request fails", async () => {
    let attempts = 0;
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal()])),
      [CHECK]: () => (++attempts === 1 ? errorResponse(500, "internal_error") : jsonResponse(200, goalDay())),
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Feito" }));

    expect(await screen.findByText("Algo deu errado do nosso lado. Tente de novo em instantes.")).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Feito", selected: false })).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Tentar de novo" }));

    await waitFor(() => expect(screen.getByRole("button", { name: "Feito", selected: true })).toBeOnTheScreen());
    expect(screen.queryByRole("button", { name: "Tentar de novo" })).toBeNull();
  });

  it("does not change state before the answer arrives", async () => {
    let release: (value: unknown) => void = () => {};
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal()])),
      [CHECK]: () => new Promise((resolve) => (release = resolve)) as never,
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await fireEvent.press(await screen.findByRole("button", { name: "Feito" }));
    expect(screen.getByRole("button", { name: "Feito", busy: true, selected: false })).toBeOnTheScreen();
    release(jsonResponse(200, goalDay()));
    await waitFor(() => expect(screen.getByRole("button", { name: "Feito", selected: true, busy: false })).toBeOnTheScreen());
  });

  it("after midnight an outside_window answer shows the message and reloads", async () => {
    let loads = 0;
    const ctx = makeApi({
      [LIST]: () => {
        loads += 1;
        return jsonResponse(200, loads === 1 ? goalList([goal()]) : { today_local_date: "2026-11-27", yesterday_local_date: TODAY, goals: [goal({ done_yesterday: true })] });
      },
      [UNCHECK(YESTERDAY)]: jsonResponse(422, outsideWindow),
      [CHECK]: jsonResponse(422, outsideWindow),
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await screen.findByText("Registrar as refeições do dia");
    await fireEvent.press(screen.getByRole("radio", { name: "Ontem" }));
    await fireEvent.press(screen.getByRole("button", { name: "Feito" }));

    expect(await screen.findByText("Só dá para marcar hoje ou ontem.")).toBeOnTheScreen();
    await waitFor(() => expect(loads).toBe(2));
    // The reloaded list says what is done now; nothing was marked by the refused request.
    expect(screen.getByRole("button", { name: "Feito", selected: true })).toBeOnTheScreen();
  });

  it("a goal created today offers no done button for yesterday", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal({ starts_on: TODAY }), goal({ id: WATER_ID, goal_type: "drink_water", starts_on: YESTERDAY })])) });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await screen.findByText("Registrar as refeições do dia");
    expect(screen.getAllByRole("button", { name: "Feito" })).toHaveLength(2);
    await fireEvent.press(screen.getByRole("radio", { name: "Ontem" }));

    expect(screen.getAllByRole("button", { name: "Feito" })).toHaveLength(1);
    expect(screen.getByText("Beber água ao longo do dia")).toBeOnTheScreen();
  });

  it("paused goals are listed last", async () => {
    const ctx = makeApi({
      [LIST]: jsonResponse(200, goalList([goal({ status: "paused" }), goal({ id: WATER_ID, goal_type: "drink_water" }), goal({ id: SLEEP_ID, goal_type: "sleep_routine" })])),
    });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    await screen.findByText("Beber água ao longo do dia");
    const labels = ["Registrar as refeições do dia", "Beber água ao longo do dia", "Dormir no horário que escolhi"];
    const order = screen.getAllByTestId("goal-row").map((row) => labels.find((label) => within(row).queryByText(label)));
    expect(order).toEqual(["Beber água ao longo do dia", "Dormir no horário que escolhi", "Registrar as refeições do dia"]);
    expect(screen.getByText("Pausada. Retome quando quiser.")).toBeOnTheScreen();
    expect(screen.getAllByRole("button", { name: "Feito" })).toHaveLength(2);
  });

  it("empty state", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([])) });
    const props = handlers();
    await render(<GoalsTodayScreen api={ctx.api} {...props} />);

    expect(await screen.findByText("Escolha um hábito para acompanhar.")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("link", { name: "Nova meta" }));
    expect(props.onNew).toHaveBeenCalled();
  });

  it("shows an error with retry when the list does not load", async () => {
    const ctx = makeApi({ [LIST]: errorResponse(500, "internal_error") });
    await render(<GoalsTodayScreen api={ctx.api} {...handlers()} />);

    expect(await screen.findByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });

  it("opens the detail of a goal", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])) });
    const props = handlers();
    await render(<GoalsTodayScreen api={ctx.api} {...props} />);

    await fireEvent.press(await screen.findByRole("link", { name: "Ver meta: Registrar as refeições do dia" }));
    expect(props.onOpen).toHaveBeenCalledWith(MEALS_ID);
  });

  it("opens the history", async () => {
    const ctx = makeApi({ [LIST]: jsonResponse(200, goalList([goal()])) });
    const props = handlers();
    await render(<GoalsTodayScreen api={ctx.api} {...props} />);

    await fireEvent.press(await screen.findByRole("link", { name: "Histórico" }));
    expect(props.onHistory).toHaveBeenCalled();
  });
});
