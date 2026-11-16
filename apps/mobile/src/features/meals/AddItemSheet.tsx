import { useState } from "react";
import type { Api, FoodEntry, FoodItemInput } from "../../shared/api";
import { Body, Button, ErrorText, Field, Subtitle } from "../../shared/ui";
import { CatalogSearch } from "./CatalogSearch";
import { mealErrorMessage } from "./mealMessages";

type Props = { api: Api; entryId: string; onAdded: (entry: FoodEntry) => void; onClose: () => void };

type Draft = { name: string; catalogId?: string };

// Adds one item to an analyzed meal: a catalog food or a typed name, and a portion in grams. The API recalculates.
export function AddItemSheet({ api, entryId, onAdded, onClose }: Props) {
  const [draft, setDraft] = useState<Draft | null>(null);
  const [grams, setGrams] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function save() {
    const value = Number(grams.replace(",", "."));
    if (!draft) return setError("Escolha um alimento da busca ou use o nome que você digitou.");
    if (!grams.trim() || Number.isNaN(value)) return setError("Digite a quantidade em gramas.");

    const input: FoodItemInput = draft.catalogId ? { catalog_item_id: draft.catalogId, grams_likely: value } : { free_text_name: draft.name, grams_likely: value };
    setError(null);
    setBusy(true);
    const result = await api.addFoodEntryItem(entryId, input);
    setBusy(false);

    if (!result.ok) return setError(mealErrorMessage(result));
    onAdded(result.data);
  }

  return (
    <>
      <Subtitle>Adicionar item</Subtitle>
      <CatalogSearch api={api} onPick={(item) => setDraft({ name: item.name_pt, catalogId: item.id })} onUseName={(name) => setDraft({ name })} />
      {draft ? <Body>{`Escolhido: ${draft.name}`}</Body> : null}
      <Field label="Quantidade em gramas" value={grams} onChangeText={setGrams} keyboardType="decimal-pad" />
      <ErrorText>{error}</ErrorText>
      <Button label="Salvar item" busy={busy} onPress={save} />
      <Button label="Cancelar" variant="secondary" disabled={busy} onPress={onClose} />
    </>
  );
}
