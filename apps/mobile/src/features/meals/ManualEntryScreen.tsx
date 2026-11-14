import { useRef, useState } from "react";
import type { Api, FoodItemInput } from "../../shared/api";
import { Body, Button, ErrorText, Field, Screen, Subtitle, Title } from "../../shared/ui";
import { CatalogSearch } from "./CatalogSearch";
import { mealErrorMessage } from "./mealMessages";

type Props = { api: Api; onCreated: (entryId: string) => void; newId: () => string };

type Draft = { name: string; catalogId?: string };
type Line = { key: number; name: string; grams: number; input: FoodItemInput };

// A meal without a photo: foods from the catalog or typed names, and a portion in grams.
export function ManualEntryScreen({ api, onCreated, newId }: Props) {
  const [lines, setLines] = useState<Line[]>([]);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [grams, setGrams] = useState("");
  const [searchKey, setSearchKey] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // One id for the whole screen: sending again after a failed answer never doubles the meal.
  const requestId = useRef<string | null>(null);

  function addLine() {
    const value = Number(grams.replace(",", "."));
    if (!draft || !grams.trim() || Number.isNaN(value)) return setError("Digite a quantidade em gramas.");

    const input: FoodItemInput = draft.catalogId
      ? { catalog_item_id: draft.catalogId, grams_likely: value }
      : { free_text_name: draft.name, grams_likely: value };
    setLines((current) => [...current, { key: Date.now() + current.length, name: draft.name, grams: value, input }]);
    setDraft(null);
    setGrams("");
    setError(null);
    setSearchKey((key) => key + 1);
  }

  async function register() {
    setError(null);
    setBusy(true);
    requestId.current ??= newId();
    const result = await api.createManualFoodEntry({
      client_request_id: requestId.current,
      meal_at: new Date().toISOString(),
      items: lines.map((line) => line.input),
    });
    setBusy(false);

    if (!result.ok) return setError(mealErrorMessage(result));
    onCreated(result.data.id);
  }

  return (
    <Screen>
      <Title>Registrar sem foto</Title>
      <Body>Busque cada alimento e diga a quantidade. Se não achar, use o nome que você digitou.</Body>
      <CatalogSearch
        key={searchKey}
        api={api}
        onPick={(item) => setDraft({ name: item.name_pt, catalogId: item.id })}
        onUseName={(name) => setDraft({ name })}
      />
      {draft && (
        <>
          <Body>{`Escolhido: ${draft.name}`}</Body>
          <Field label="Quantidade em gramas" value={grams} onChangeText={setGrams} keyboardType="decimal-pad" />
          <Button label="Adicionar à refeição" onPress={addLine} />
        </>
      )}
      <ErrorText>{error}</ErrorText>
      {lines.length > 0 && <Subtitle>Itens da refeição</Subtitle>}
      {lines.map((line) => (
        <Button
          key={line.key}
          label={`Remover ${line.name}`}
          variant="secondary"
          onPress={() => setLines((current) => current.filter((other) => other.key !== line.key))}
        />
      ))}
      {lines.map((line) => (
        <Body key={`text-${line.key}`}>{`${line.name} · ${line.grams} g`}</Body>
      ))}
      <Button label="Registrar refeição" busy={busy} disabled={lines.length === 0} onPress={register} />
    </Screen>
  );
}
