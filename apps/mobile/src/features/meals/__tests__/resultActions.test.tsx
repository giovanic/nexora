import { fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import { errorResponse, jsonResponse, makeApi } from "../../../shared/testing/fakes";
import { ENTRY_ID, ITEM_ID, NO_NUMBERS, foodEntry, foodItem } from "../../../shared/testing/mealFakes";
import { MealResultScreen } from "../MealResultScreen";

const GET = `GET /api/v1/food_entries/${ENTRY_ID}`;
const DELETE_ENTRY = `DELETE /api/v1/food_entries/${ENTRY_ID}`;
const ANALYSIS = `POST /api/v1/food_entries/${ENTRY_ID}/analysis`;
const CATALOG_ID = "66666666-6666-4666-8666-666666666666";

function setup(routes: Record<string, unknown>) {
  const ctx = makeApi(routes as never);
  const handlers = { onManual: jest.fn(), onNewPhoto: jest.fn(), onDone: jest.fn(), onDeleted: jest.fn() };
  const element = <MealResultScreen api={ctx.api} entryId={ENTRY_ID} {...handlers} />;
  const count = (key: string) => ctx.calls.filter((call) => call.key === key).length;
  return { ...ctx, ...handlers, element, count };
}

const failedEntry = () => jsonResponse(200, foodEntry({ status: "failed", ...NO_NUMBERS }));

describe("MealResultScreen actions", () => {
  it("deletes the meal after a confirmation and goes back to the history", async () => {
    const { element, onDeleted, count } = setup({ [GET]: jsonResponse(200, foodEntry()), [DELETE_ENTRY]: jsonResponse(204) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Apagar refeição" }));
    expect(count(DELETE_ENTRY)).toBe(0);
    expect(screen.getByText(/A foto e os itens serão apagados/)).toBeOnTheScreen();
    await fireEvent.press(screen.getByRole("button", { name: "Sim, apagar" }));

    await waitFor(() => expect(onDeleted).toHaveBeenCalledTimes(1));
    expect(count(DELETE_ENTRY)).toBe(1);
  });

  it("cancelling the confirmation deletes nothing", async () => {
    const { element, onDeleted, count } = setup({ [GET]: jsonResponse(200, foodEntry()) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Apagar refeição" }));
    await fireEvent.press(screen.getByRole("button", { name: "Cancelar" }));

    expect(count(DELETE_ENTRY)).toBe(0);
    expect(onDeleted).not.toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Apagar refeição" })).toBeOnTheScreen();
  });

  it("shows the error when the deletion fails and stays on the meal", async () => {
    const { element, onDeleted } = setup({ [GET]: jsonResponse(200, foodEntry()), [DELETE_ENTRY]: errorResponse(500, "internal_error") });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Apagar refeição" }));
    await fireEvent.press(screen.getByRole("button", { name: "Sim, apagar" }));

    expect(await screen.findByText(/Algo deu errado do nosso lado/)).toBeOnTheScreen();
    expect(onDeleted).not.toHaveBeenCalled();
  });

  it("offers to delete a meal that failed too", async () => {
    const { element, onDeleted } = setup({ [GET]: failedEntry(), [DELETE_ENTRY]: jsonResponse(204) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Apagar refeição" }));
    await fireEvent.press(screen.getByRole("button", { name: "Sim, apagar" }));

    await waitFor(() => expect(onDeleted).toHaveBeenCalled());
  });

  it("removes an item and shows the recalculated meal", async () => {
    const second = foodItem({ id: "77777777-7777-4777-8777-777777777777", name: "Feijão" });
    const after = foodEntry({ calories_min: 100, calories_max: 140, items: [second] });
    const { element, calls } = setup({
      [GET]: jsonResponse(200, foodEntry({ items: [foodItem(), second] })),
      [`DELETE /api/v1/food_entries/${ENTRY_ID}/items/${ITEM_ID}`]: jsonResponse(200, after),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Remover Arroz branco" }));

    expect(await screen.findByText("Refeição: cerca de 100 a 140 kcal")).toBeOnTheScreen();
    expect(screen.queryByText("Arroz branco")).toBeNull();
    expect(calls.some((call) => call.key.startsWith("DELETE"))).toBe(true);
  });

  it("shows the error when removing an item fails", async () => {
    const { element } = setup({
      [GET]: jsonResponse(200, foodEntry()),
      [`DELETE /api/v1/food_entries/${ENTRY_ID}/items/${ITEM_ID}`]: errorResponse(409, "entry_not_editable"),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Remover Arroz branco" }));

    expect(await screen.findByText(/não pode ser alterada agora/)).toBeOnTheScreen();
    expect(screen.getByText("Arroz branco")).toBeOnTheScreen();
  });

  it("adds a free-text item with its grams", async () => {
    const after = foodEntry({ estimate_partial: true, items: [foodItem(), foodItem({ id: "88888888-8888-4888-8888-888888888888", name: "Pão", unknown: true, source: null, calories_min: null, calories_max: null })] });
    const { element, calls } = setup({ [GET]: jsonResponse(200, foodEntry()), [`POST /api/v1/food_entries/${ENTRY_ID}/items`]: jsonResponse(201, after) });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Adicionar item" }));
    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "Pão");
    await fireEvent.press(screen.getByRole("button", { name: "Usar este nome" }));
    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "50");
    await fireEvent.press(screen.getByRole("button", { name: "Salvar item" }));

    expect(await screen.findByText("Pão")).toBeOnTheScreen();
    const post = calls.find((call) => call.key === `POST /api/v1/food_entries/${ENTRY_ID}/items`);
    expect(JSON.parse(post?.init.body as string)).toEqual({ free_text_name: "Pão", grams_likely: 50 });
    expect(screen.queryByRole("button", { name: "Salvar item" })).toBeNull();
  });

  it("adds a catalog item found by search", async () => {
    const after = foodEntry({ items: [foodItem(), foodItem({ id: "99999999-9999-4999-8999-999999999999", name: "Arroz integral" })] });
    const { element, calls } = setup({
      [GET]: jsonResponse(200, foodEntry()),
      "POST /api/v1/foods/search": jsonResponse(200, { items: [{ id: CATALOG_ID, name_pt: "Arroz integral", kind: "ingredient", source: "usda_fdc" }], next_page: null }),
      [`POST /api/v1/food_entries/${ENTRY_ID}/items`]: jsonResponse(201, after),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Adicionar item" }));
    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "arroz int");
    await fireEvent.press(screen.getByRole("button", { name: "Buscar" }));
    await fireEvent.press(await screen.findByRole("button", { name: "Usar Arroz integral" }));
    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "80,5");
    await fireEvent.press(screen.getByRole("button", { name: "Salvar item" }));

    expect(await screen.findByText("Arroz integral")).toBeOnTheScreen();
    const post = calls.find((call) => call.key === `POST /api/v1/food_entries/${ENTRY_ID}/items`);
    expect(JSON.parse(post?.init.body as string)).toEqual({ catalog_item_id: CATALOG_ID, grams_likely: 80.5 });
  });

  it("asks for the grams before adding and maps a refused item", async () => {
    const { element, count } = setup({
      [GET]: jsonResponse(200, foodEntry()),
      [`POST /api/v1/food_entries/${ENTRY_ID}/items`]: errorResponse(422, "validation_failed"),
    });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Adicionar item" }));
    await fireEvent.changeText(screen.getByLabelText("Buscar alimento"), "Pão");
    await fireEvent.press(screen.getByRole("button", { name: "Usar este nome" }));
    await fireEvent.press(screen.getByRole("button", { name: "Salvar item" }));
    expect(await screen.findByText("Digite a quantidade em gramas.")).toBeOnTheScreen();
    expect(count(`POST /api/v1/food_entries/${ENTRY_ID}/items`)).toBe(0);

    await fireEvent.changeText(screen.getByLabelText("Quantidade em gramas"), "5000");
    await fireEvent.press(screen.getByRole("button", { name: "Salvar item" }));
    expect(await screen.findByText(/entre 1 e 2000 g/)).toBeOnTheScreen();
  });

  it("an analyzed meal with no items and no result code shows an empty state and still allows adding", async () => {
    const { element } = setup({ [GET]: jsonResponse(200, foodEntry({ ...NO_NUMBERS })) });
    await render(element);

    expect(await screen.findByText(/Esta refeição não tem itens/)).toBeOnTheScreen();
    expect(screen.getByRole("button", { name: "Adicionar item" })).toBeOnTheScreen();
  });

  describe("failed analysis", () => {
    it("offers another photo", async () => {
      const { element, onNewPhoto } = setup({ [GET]: failedEntry() });
      await render(element);

      await fireEvent.press(await screen.findByRole("button", { name: "Tirar outra foto" }));

      expect(onNewPhoto).toHaveBeenCalledTimes(1);
    });

    it("shows the error of a retry refused by the rate limit", async () => {
      const { element } = setup({ [GET]: failedEntry(), [ANALYSIS]: errorResponse(429, "rate_limited", { "Retry-After": "60" }) });
      await render(element);

      await fireEvent.press(await screen.findByRole("button", { name: "Tentar de novo" }));

      expect(await screen.findByText(/Muitas tentativas/)).toBeOnTheScreen();
    });

    it("not_uploaded says the photo is gone and stops offering the retry", async () => {
      const { element } = setup({ [GET]: failedEntry(), [ANALYSIS]: errorResponse(422, "not_uploaded") });
      await render(element);

      await fireEvent.press(await screen.findByRole("button", { name: "Tentar de novo" }));

      expect(await screen.findByText(/A foto não está mais disponível/)).toBeOnTheScreen();
      expect(screen.queryByRole("button", { name: "Tentar de novo" })).toBeNull();
      expect(screen.getByRole("button", { name: "Tirar outra foto" })).toBeOnTheScreen();
    });

    it("analysis_retry_limit has its own message and no retry", async () => {
      const { element } = setup({ [GET]: failedEntry(), [ANALYSIS]: errorResponse(409, "analysis_retry_limit") });
      await render(element);

      await fireEvent.press(await screen.findByRole("button", { name: "Tentar de novo" }));

      expect(await screen.findByText(/já foi analisada o máximo de vezes/)).toBeOnTheScreen();
      expect(screen.queryByRole("button", { name: "Tentar de novo" })).toBeNull();
    });

    it("analysis_quota_exceeded says when the limit resets", async () => {
      const { element } = setup({ [GET]: failedEntry(), [ANALYSIS]: errorResponse(429, "analysis_quota_exceeded", { "Retry-After": "7200" }) });
      await render(element);

      await fireEvent.press(await screen.findByRole("button", { name: "Tentar de novo" }));

      expect(await screen.findByText(/volta em cerca de 2 horas/)).toBeOnTheScreen();
    });
  });

  it("a meal with no food shows an error from a failed deletion", async () => {
    const { element } = setup({ [GET]: jsonResponse(200, foodEntry({ result_code: "no_food", ...NO_NUMBERS })), [DELETE_ENTRY]: errorResponse(500, "internal_error") });
    await render(element);

    await fireEvent.press(await screen.findByRole("button", { name: "Apagar refeição" }));
    await fireEvent.press(screen.getByRole("button", { name: "Sim, apagar" }));

    expect(await screen.findByText(/Algo deu errado do nosso lado/)).toBeOnTheScreen();
  });
});
