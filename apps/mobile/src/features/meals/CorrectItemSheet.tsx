import { useState } from "react";
import type { Api, FoodCatalogItem, FoodEntry, FoodEntryItem } from "../../shared/api";
import { Button, ErrorText, Field, Subtitle } from "../../shared/ui";
import { CatalogSearch } from "./CatalogSearch";
import { mealErrorMessage } from "./mealMessages";

type Props = { api: Api; entryId: string; item: FoodEntryItem; onCorrected: (entry: FoodEntry) => void; onClose: () => void };

// Corrects one item: another food from the catalog, another portion, or both. The API recalculates.
export function CorrectItemSheet({ api, entryId, item, onCorrected, onClose }: Props) {
  const [grams, setGrams] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const typedGrams = () => (grams.trim() ? Number(grams.replace(",", ".")) : undefined);

  async function submit(changes: { catalog_item_id?: string; grams_likely?: number }) {
    setError(null);
    setBusy(true);
    const result = await api.correctFoodEntryItem(entryId, item.id, changes);
    setBusy(false);

    if (!result.ok) return setError(mealErrorMessage(result));
    onCorrected(result.data);
  }

  function saveGrams() {
    const value = typedGrams();
    if (value === undefined || Number.isNaN(value)) return setError("Digite a quantidade em gramas.");
    return submit({ grams_likely: value });
  }

  function pick(food: FoodCatalogItem) {
    const value = typedGrams();
    if (value !== undefined && Number.isNaN(value)) return setError("Digite a quantidade em gramas, só com números.");
    return submit(value === undefined ? { catalog_item_id: food.id } : { catalog_item_id: food.id, grams_likely: value });
  }

  return (
    <>
      <Subtitle>{`Corrigir ${item.name}`}</Subtitle>
      <CatalogSearch api={api} onPick={pick} />
      <Field label="Quantidade em gramas" value={grams} onChangeText={setGrams} keyboardType="decimal-pad" />
      <ErrorText>{error}</ErrorText>
      <Button label="Salvar quantidade" busy={busy} onPress={saveGrams} />
      <Button label="Cancelar" variant="secondary" disabled={busy} onPress={onClose} />
    </>
  );
}
