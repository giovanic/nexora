import { Fragment, useState } from "react";
import type { Api, FoodCatalogItem } from "../../shared/api";
import { Body, Button, ErrorText, Field, LoadingView } from "../../shared/ui";
import { mealErrorMessage } from "./mealMessages";

type Props = {
  api: Api;
  onPick: (item: FoodCatalogItem) => void;
  // When set, the typed name can be used as it is (a food the catalog does not know).
  onUseName?: (name: string) => void;
};

export const originText = (kind: FoodCatalogItem["kind"]) => (kind === "composition" ? "composição própria" : "USDA");

// Search of the food catalog by name. Every result comes ready from the API.
export function CatalogSearch({ api, onPick, onUseName }: Props) {
  const [term, setTerm] = useState("");
  const [items, setItems] = useState<FoodCatalogItem[] | null>(null);
  const [nextPage, setNextPage] = useState<number | null>(null);
  const [searched, setSearched] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function search(page: number) {
    const text = page === 1 ? term.trim() : searched;
    if (!text) return setError("Digite o nome de um alimento.");

    setError(null);
    setBusy(true);
    const result = await api.searchFoods(text, page);
    setBusy(false);

    if (!result.ok) return setError(mealErrorMessage(result));
    setSearched(text);
    setItems(page === 1 ? result.data.items : [...(items ?? []), ...result.data.items]);
    setNextPage(result.data.next_page);
  }

  return (
    <>
      <Field label="Buscar alimento" value={term} onChangeText={setTerm} autoCapitalize="sentences" returnKeyType="search" onSubmitEditing={() => search(1)} />
      <Button label="Buscar" variant="secondary" busy={busy} onPress={() => search(1)} />
      {onUseName ? <Button label="Usar este nome" variant="secondary" disabled={!term.trim()} onPress={() => onUseName(term.trim())} /> : null}
      <ErrorText>{error}</ErrorText>
      {busy && items === null && <LoadingView label="Buscando…" />}
      {items !== null && items.length === 0 && <Body>Nenhum alimento encontrado com esse nome.</Body>}
      {items?.map((item) => (
        <Fragment key={item.id}>
          <Button label={`Usar ${item.name_pt}`} variant="secondary" onPress={() => onPick(item)} />
          <Body>{`Origem: ${originText(item.kind)}`}</Body>
        </Fragment>
      ))}
      {nextPage ? <Button label="Mais resultados" variant="secondary" busy={busy} onPress={() => search(nextPage)} /> : null}
    </>
  );
}
