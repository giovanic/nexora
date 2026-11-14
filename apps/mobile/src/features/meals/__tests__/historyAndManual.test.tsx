import { fireEvent, render, screen } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { ENTRY_ID, foodEntry } from "../../../shared/testing/mealFakes";
import { ManualEntryScreen } from "../ManualEntryScreen";
import { MealHistoryScreen } from "../MealHistoryScreen";

describe("MealHistoryScreen", () => {
  const second = "77777777-7777-4777-8777-777777777777";
  const third = "88888888-8888-4888-8888-888888888888";

  it("history paginates and shows no daily total", async () => {
    const page1 = { items: [foodEntry(), foodEntry({ id: second, meal_at: "2026-11-13T11:00:00Z" })], next_cursor: "c1" };
    const page2 = { items: [foodEntry({ id: third, local_date: "2026-11-12", calories_min: 200, calories_max: 260 })], next_cursor: null };
    const ctx = makeApi({ "GET /api/v1/food_entries": jsonResponse(200, page1), "GET /api/v1/food_entries?cursor=c1": jsonResponse(200, page2) });
    const onOpen = jest.fn();
    await render(<MealHistoryScreen api={ctx.api} onOpen={onOpen} onNewMeal={jest.fn()} />);

    expect(await screen.findByRole("heading", { name: "13/11/2026" })).toBeOnTheScreen();
    expect(screen.getAllByText("cerca de 420 a 610 kcal")).toHaveLength(2);
    await fireEvent.press(screen.getByRole("button", { name: "Ver mais" }));

    expect(await screen.findByRole("heading", { name: "12/11/2026" })).toBeOnTheScreen();
    expect(screen.getByText("cerca de 200 a 260 kcal")).toBeOnTheScreen();
    expect(screen.queryByRole("button", { name: "Ver mais" })).toBeNull();
    expect(screen.queryByText(/total|soma|restante|dia/i)).toBeNull();
    expect(screen.queryByText(/\b1[0-9]{3}\b/)).toBeNull();

    await fireEvent.press(screen.getAllByRole("button", { name: /Abrir refeição/ })[0]);
    expect(onOpen).toHaveBeenCalledWith(ENTRY_ID);
  });

  it("shows loading while the first page loads", async () => {
    const waiting = makeApi({ "GET /api/v1/food_entries": () => new Promise<never>(() => {}) } as never);
    const timers = jest.useFakeTimers();
    await render(<MealHistoryScreen api={waiting.api} onOpen={jest.fn()} onNewMeal={jest.fn()} />);

    expect(screen.getByText("Carregando…")).toBeOnTheScreen();
    timers.clearAllTimers();
    jest.useRealTimers();
  });

  it("shows the empty state", async () => {
    const empty = makeApi({ "GET /api/v1/food_entries": jsonResponse(200, { items: [], next_cursor: null }) });
    await render(<MealHistoryScreen api={empty.api} onOpen={jest.fn()} onNewMeal={jest.fn()} />);

    expect(await screen.findByText("Você ainda não registrou nenhuma refeição.")).toBeOnTheScreen();
  });

  it("shows an error with retry", async () => {
    const failing = makeApi({ "GET /api/v1/food_entries": errorResponse(500, "internal_error") });
    await render(<MealHistoryScreen api={failing.api} onOpen={jest.fn()} onNewMeal={jest.fn()} />);

    expect(await screen.findByRole("button", { name: "Tentar de novo" })).toBeOnTheScreen();
  });
});

describe("ManualEntryScreen", () => {
  it("registers a meal from catalog items and free text, with one client_request_id", async () => {
    const catalogId = "66666666-6666-4666-8666-666666666666";
    const ctx = makeApi({
      "POST /api/v1/foods/search": jsonResponse(200, { items: [{ id: catalogId, name_pt: "Feijão cozido", kind: "ingredient", source: "usda_fdc" }], next_page: null }),
      "POST /api/v1/food_entries": jsonResponse(201, foodEntry({ source: "manual", status: "confirmed" })),
    });
    const onCreated = jest.fn();
    await render(<ManualEntryScreen api={ctx.api} onCreated={onCreated} newId={() => "manual-1"} />);

    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "feij");
    await fireEvent.press(screen.getByRole("button", { name: "Buscar" }));
    await fireEvent.press(await screen.findByRole("button", { name: "Usar Feijão cozido" }));
    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "150");
    await fireEvent.press(screen.getByRole("button", { name: "Adicionar à refeição" }));

    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "Prato da vovó");
    await fireEvent.press(screen.getByRole("button", { name: "Usar este nome" }));
    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "200");
    await fireEvent.press(screen.getByRole("button", { name: "Adicionar à refeição" }));

    expect(screen.getByText("Feijão cozido · 150 g")).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Registrar refeição" }));

    expect(onCreated).toHaveBeenCalledWith(ENTRY_ID);
    const post = ctx.calls.find((call) => call.key === "POST /api/v1/food_entries");
    const body = JSON.parse(post?.init.body as string);
    expect(body.client_request_id).toBe("manual-1");
    expect(body.meal_at).toMatch(/Z$|[+-]\d\d:\d\d$/);
    expect(body.items).toEqual([
      { catalog_item_id: catalogId, grams_likely: 150 },
      { free_text_name: "Prato da vovó", grams_likely: 200 },
    ]);
  });

  it("does not send an empty meal and maps validation_failed", async () => {
    const ctx = makeApi({ "POST /api/v1/food_entries": errorResponse(422, "validation_failed") });
    await render(<ManualEntryScreen api={ctx.api} onCreated={jest.fn()} newId={() => "manual-1"} />);

    expect(screen.getByRole("button", { name: "Registrar refeição" })).toBeDisabled();

    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "Pão");
    await fireEvent.press(screen.getByRole("button", { name: "Usar este nome" }));
    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "5000");
    await fireEvent.press(screen.getByRole("button", { name: "Adicionar à refeição" }));
    await fireEvent.press(screen.getByRole("button", { name: "Registrar refeição" }));

    expect(await screen.findByText(/entre 1 e 2000 g/)).toBeOnTheScreen();
  });
});
