import { act, fireEvent, render, screen } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi, type Route } from "../../../shared/testing/fakes";
import { ENTRY_ID, ITEM_ID, NO_NUMBERS, analysisAccepted, foodEntry, foodItem } from "../../../shared/testing/mealFakes";
import { MealResultScreen } from "../MealResultScreen";

const GET = `GET /api/v1/food_entries/${ENTRY_ID}`;
const entryRoute = (entry = foodEntry()) => jsonResponse(200, entry);

function sequence(...entries: ReturnType<typeof foodEntry>[]): Route {
  let index = 0;
  return () => jsonResponse(200, entries[Math.min(index++, entries.length - 1)]);
}

function setup(routes: Record<string, unknown>) {
  const ctx = makeApi(routes as never);
  const handlers = { onManual: jest.fn(), onNewPhoto: jest.fn(), onDone: jest.fn() };
  const element = <MealResultScreen api={ctx.api} entryId={ENTRY_ID} {...handlers} />;
  const count = (key: string) => ctx.calls.filter((call) => call.key === key).length;
  return { ...ctx, ...handlers, element, count };
}

const tick = (ms: number) => act(async () => jest.advanceTimersByTimeAsync(ms));

describe("MealResultScreen", () => {
  beforeEach(() => jest.useFakeTimers());
  afterEach(() => jest.useRealTimers());

  it("pending, processing, analyzed and failed states", async () => {
    const { element, count } = setup({
      [GET]: sequence(foodEntry({ status: "pending", ...NO_NUMBERS }), foodEntry({ status: "processing", ...NO_NUMBERS }), foodEntry({ status: "analyzed" })),
    });
    await render(element);

    expect(await screen.findByText("Aguardando a foto chegar ao servidor…")).toBeOnTheScreen();
    await tick(3000);
    expect(await screen.findByText("Analisando a foto…")).toBeOnTheScreen();
    await tick(3000);
    expect(await screen.findByText("Arroz branco")).toBeOnTheScreen();
    await tick(9000);
    expect(count(GET)).toBe(3);
  });

  it("failed offers to try again and watches the new analysis", async () => {
    const { element, count } = setup({
      [GET]: sequence(foodEntry({ status: "failed", ...NO_NUMBERS }), foodEntry({ status: "processing", ...NO_NUMBERS })),
      [`POST /api/v1/food_entries/${ENTRY_ID}/analysis`]: analysisAccepted(),
    });
    await render(element);

    expect(await screen.findByText(/Não foi possível analisar esta foto/)).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Tentar de novo" }));

    expect(await screen.findByText("Analisando a foto…")).toBeOnTheScreen();
    expect(count(`POST /api/v1/food_entries/${ENTRY_ID}/analysis`)).toBe(1);
  });

  it("stops polling after 90 seconds and offers to refresh", async () => {
    const { element, count } = setup({ [GET]: entryRoute(foodEntry({ status: "processing", ...NO_NUMBERS })) });
    await render(element);
    await screen.findByText("Analisando a foto…");

    await tick(90_000);
    expect(await screen.findByText(/Ainda estamos analisando/)).toBeOnTheScreen();
    const polled = count(GET);
    await tick(30_000);
    expect(count(GET)).toBe(polled);

    await fireEvent.press(screen.getByRole("button", { name: "Atualizar" }));
    await tick(0);
    expect(count(GET)).toBe(polled + 1);
  });

  it("a meal still pending after 90 seconds also offers to refresh", async () => {
    const { element, count } = setup({ [GET]: entryRoute(foodEntry({ status: "pending", ...NO_NUMBERS })) });
    await render(element);
    await screen.findByText("Aguardando a foto chegar ao servidor…");

    await tick(90_000);
    expect(await screen.findByText(/Ainda estamos esperando/)).toBeOnTheScreen();
    const polled = count(GET);

    await fireEvent.press(screen.getByRole("button", { name: "Atualizar" }));
    await tick(0);
    expect(count(GET)).toBe(polled + 1);
  });

  it.each([
    ["no_food", /Não encontramos comida nesta foto/],
    ["unreadable", /Não conseguimos ler esta foto/],
  ])("%s shows a message and no numbers", async (code, message) => {
    const { element, onNewPhoto, onManual } = setup({ [GET]: entryRoute(foodEntry({ result_code: code as "no_food", ...NO_NUMBERS })) });
    await render(element);

    expect(await screen.findByText(message)).toBeOnTheScreen();
    expect(screen.queryByText(/\d/)).toBeNull();
    expect(screen.queryByText(/kcal/)).toBeNull();
    expect(screen.queryByRole("button", { name: "Confirmar" })).toBeNull();
    await fireEvent.press(screen.getByRole("button", { name: "Tirar outra foto" }));
    expect(onNewPhoto).toHaveBeenCalledTimes(1);
    await fireEvent.press(screen.getByRole("link", { name: "Registrar sem foto" }));
    expect(onManual).toHaveBeenCalledTimes(1);
  });

  it("ranges render without decimals and with the source", async () => {
    const entry = foodEntry({
      items: [
        foodItem({ quantity_grams_likely: 123.6, calories_min: 420, calories_max: 610 }),
        foodItem({ id: "33333333-3333-4333-8333-333333333333", name: "Feijoada", source: "project", own_composition: true, calories_min: 300, calories_max: 380, quantity_grams_likely: 200 }),
      ],
    });
    const { element } = setup({ [GET]: entryRoute(entry) });
    await render(element);

    expect(await screen.findByText("cerca de 420 a 610 kcal")).toBeOnTheScreen();
    expect(screen.getByText("cerca de 124 g · 3 colheres de sopa")).toBeOnTheScreen();
    expect(screen.getByText("Origem: USDA")).toBeOnTheScreen();
    expect(screen.getByText("Origem: composição própria")).toBeOnTheScreen();
    expect(screen.getByText("Estimativa com confiança média")).toBeOnTheScreen();
    expect(screen.getByText("Refeição: cerca de 420 a 610 kcal")).toBeOnTheScreen();
    expect(screen.queryByText(/\d[.,]\d/)).toBeNull();
    expect(screen.queryByText(/total|restante|hoje/i)).toBeNull();
  });

  it("names only the sources it knows and falls back to a neutral label", async () => {
    const entry = foodEntry({
      items: [
        foodItem({ source: "usda_fdc" }),
        foodItem({ id: "33333333-3333-4333-8333-333333333333", name: "Pão", source: "project", own_composition: false }),
        foodItem({ id: "44444444-4444-4444-8444-444444444444", name: "Queijo", source: "other_base" as never }),
      ],
    });
    const { element } = setup({ [GET]: entryRoute(entry) });
    await render(element);

    expect(await screen.findAllByText("Origem: USDA")).toHaveLength(1);
    expect(screen.getAllByText("Origem: composição própria")).toHaveLength(1);
    expect(screen.getAllByText("Origem: base de dados")).toHaveLength(1);
  });

  it("partial estimate label", async () => {
    const entry = foodEntry({
      estimate_partial: true,
      unknown_items_count: 1,
      items: [foodItem(), foodItem({ id: "44444444-4444-4444-8444-444444444444", name: "Prato da vovó", unknown: true, source: null, calories_min: null, calories_likely: null, calories_max: null })],
    });
    const { element } = setup({ [GET]: entryRoute(entry) });
    await render(element);

    expect(await screen.findByText("Estimativa parcial: alguns itens não têm números")).toBeOnTheScreen();
    expect(screen.getByText("Sem estimativa para este item")).toBeOnTheScreen();
  });

  it("confirm sends one request", async () => {
    const confirmed = foodEntry({ status: "confirmed" });
    const { element, count, onDone } = setup({ [GET]: entryRoute(), [`POST /api/v1/food_entries/${ENTRY_ID}/confirmation`]: jsonResponse(200, confirmed) });
    await render(element);

    const button = await screen.findByRole("button", { name: "Confirmar" });
    await fireEvent.press(button);
    await fireEvent.press(button);

    expect(await screen.findByText("Refeição confirmada")).toBeOnTheScreen();
    expect(count(`POST /api/v1/food_entries/${ENTRY_ID}/confirmation`)).toBe(1);
    expect(screen.queryByRole("button", { name: "Confirmar" })).toBeNull();
    expect(onDone).not.toHaveBeenCalled();
  });

  it("maps a confirmation refused with entry_not_confirmable", async () => {
    const { element } = setup({ [GET]: entryRoute(), [`POST /api/v1/food_entries/${ENTRY_ID}/confirmation`]: errorResponse(409, "entry_not_confirmable") });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Confirmar" }));

    expect(await screen.findByText(/ainda não pode ser confirmada/)).toBeOnTheScreen();
  });

  it("correct searches the catalog and shows the new range", async () => {
    const corrected = foodEntry({
      calories_min: 300,
      calories_max: 380,
      items: [foodItem({ id: "55555555-5555-4555-8555-555555555555", name: "Arroz integral", origin: "user", calories_min: 300, calories_max: 380 })],
    });
    const { element, calls } = setup({
      [GET]: entryRoute(),
      "POST /api/v1/foods/search": jsonResponse(200, { items: [{ id: "66666666-6666-4666-8666-666666666666", name_pt: "Arroz integral", kind: "ingredient", source: "usda_fdc" }], next_page: null }),
      [`PATCH /api/v1/food_entries/${ENTRY_ID}/items/${ITEM_ID}`]: jsonResponse(200, corrected),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Corrigir Arroz branco" }));
    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "arroz int");
    await fireEvent.press(screen.getByRole("button", { name: "Buscar" }));
    await fireEvent.press(await screen.findByRole("button", { name: "Usar Arroz integral" }));

    expect(await screen.findByText("Refeição: cerca de 300 a 380 kcal")).toBeOnTheScreen();
    expect(screen.queryByText("Arroz branco")).toBeNull();
    const search = calls.find((call) => call.key === "POST /api/v1/foods/search");
    expect(JSON.parse(search?.init.body as string)).toMatchObject({ term: "arroz int" });
    const patch = calls.find((call) => call.key.startsWith("PATCH"));
    expect(JSON.parse(patch?.init.body as string)).toEqual({ catalog_item_id: "66666666-6666-4666-8666-666666666666" });
  });

  it("corrects only the portion and maps validation_failed", async () => {
    const { element, calls } = setup({
      [GET]: entryRoute(),
      [`PATCH /api/v1/food_entries/${ENTRY_ID}/items/${ITEM_ID}`]: errorResponse(422, "validation_failed"),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Corrigir Arroz branco" }));
    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "5000");
    await fireEvent.press(screen.getByRole("button", { name: "Salvar quantidade" }));

    expect(await screen.findByText(/entre 1 e 2000 g/)).toBeOnTheScreen();
    const patch = calls.find((call) => call.key.startsWith("PATCH"));
    expect(JSON.parse(patch?.init.body as string)).toEqual({ grams_likely: 5000 });
  });

  it("shows an error with retry and not found", async () => {
    const { element } = setup({ [GET]: errorResponse(404, "not_found") });
    await render(element);

    expect(await screen.findByText(/Não encontramos esta refeição/)).toBeOnTheScreen();
  });
});
