import { useCallback, useEffect, useRef, useState } from "react";
import type { Api, Failure, FoodEntry, FoodEntryItem } from "../../shared/api";
import { Body, Button, ErrorText, ErrorView, InfoText, LinkButton, LoadingView, Screen, Subtitle, Title } from "../../shared/ui";
import { CorrectItemSheet } from "./CorrectItemSheet";
import { gramsText, kcalRange } from "./formatRange";
import { NO_FOOD_MESSAGE, UNREADABLE_MESSAGE, mealErrorMessage } from "./mealMessages";

export const POLL_EVERY_MS = 3_000;
export const POLL_UNTIL_MS = 90_000;

type Props = {
  api: Api;
  entryId: string;
  onNewPhoto: () => void;
  onManual: () => void;
  onDone: () => void;
};

type State = { status: "loading" } | { status: "error"; error: Failure } | { status: "ready"; entry: FoodEntry };

const CONFIDENCE = { high: "alta", medium: "média", low: "baixa" } as const;

function itemOrigin(item: FoodEntryItem): string | null {
  if (item.source === null) return null;
  return item.own_composition || item.source === "project" ? "composição própria" : "USDA";
}

function ItemCard({ item, onCorrect }: { item: FoodEntryItem; onCorrect: () => void }) {
  const range = item.unknown ? null : kcalRange(item.calories_min, item.calories_max);
  const origin = itemOrigin(item);
  const portion = [gramsText(item.quantity_grams_likely), item.household_measure].filter(Boolean).join(" · ");
  return (
    <>
      <Body>{item.name}</Body>
      <Body>{range ?? "Sem estimativa para este item"}</Body>
      <Body>{portion}</Body>
      {origin ? <Body>{`Origem: ${origin}`}</Body> : null}
      <Button label={`Corrigir ${item.name}`} variant="secondary" onPress={onCorrect} />
    </>
  );
}

export function MealResultScreen({ api, entryId, onNewPhoto, onManual, onDone }: Props) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [round, setRound] = useState(0);
  const [timedOut, setTimedOut] = useState(false);
  const [editing, setEditing] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const confirming = useRef(false);

  // Asks every 3 s while the meal is pending or processing, up to 90 s, then waits for "Atualizar".
  useEffect(() => {
    let live = true;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let waited = 0;

    async function poll() {
      const result = await api.getFoodEntry(entryId);
      if (!live) return;
      if (!result.ok) return setState({ status: "error", error: result });

      setState({ status: "ready", entry: result.data });
      if (result.data.status !== "pending" && result.data.status !== "processing") return;
      if (waited >= POLL_UNTIL_MS) return setTimedOut(true);
      timer = setTimeout(() => {
        waited += POLL_EVERY_MS;
        void poll();
      }, POLL_EVERY_MS);
    }

    void poll();
    return () => {
      live = false;
      clearTimeout(timer);
    };
  }, [api, entryId, round]);

  const refresh = useCallback(() => {
    setTimedOut(false);
    setRound((value) => value + 1);
  }, []);

  async function retryAnalysis() {
    setError(null);
    setBusy(true);
    const result = await api.requestFoodAnalysis(entryId);
    setBusy(false);
    if (!result.ok && result.status !== 409) return setError(mealErrorMessage(result));
    refresh();
  }

  async function confirm() {
    if (confirming.current) return;
    confirming.current = true;
    setError(null);
    setBusy(true);
    const result = await api.confirmFoodEntry(entryId);
    setBusy(false);
    confirming.current = false;

    if (!result.ok) return setError(mealErrorMessage(result));
    setState({ status: "ready", entry: result.data });
  }

  function renderEntry(entry: FoodEntry) {
    if (entry.status === "pending") return <LoadingView label="Aguardando a foto chegar ao servidor…" />;
    if (entry.status === "processing") {
      return (
        <>
          <LoadingView label="Analisando a foto…" />
          {timedOut && (
            <>
              <Body>Ainda estamos analisando. Você pode esperar mais um pouco ou atualizar.</Body>
              <Button label="Atualizar" variant="secondary" onPress={refresh} />
            </>
          )}
        </>
      );
    }
    if (entry.status === "failed") {
      return (
        <>
          <ErrorText>Não foi possível analisar esta foto.</ErrorText>
          <Button label="Tentar de novo" busy={busy} onPress={retryAnalysis} />
          <LinkButton label="Registrar sem foto" onPress={onManual} />
        </>
      );
    }
    if (entry.result_code) {
      return (
        <>
          <Body>{entry.result_code === "no_food" ? NO_FOOD_MESSAGE : UNREADABLE_MESSAGE}</Body>
          <Button label="Tirar outra foto" onPress={onNewPhoto} />
          <LinkButton label="Registrar sem foto" onPress={onManual} />
        </>
      );
    }

    const meal = kcalRange(entry.calories_min, entry.calories_max);
    return (
      <>
        {entry.status === "confirmed" && <InfoText>Refeição confirmada</InfoText>}
        {meal ? <Subtitle>{`Refeição: ${meal}`}</Subtitle> : null}
        {entry.confidence ? <Body>{`Estimativa com confiança ${CONFIDENCE[entry.confidence]}`}</Body> : null}
        {entry.estimate_partial ? <Body>Estimativa parcial: alguns itens não têm números</Body> : null}
        {entry.items.map((item) =>
          editing === item.id ? (
            <CorrectItemSheet
              key={item.id}
              api={api}
              entryId={entry.id}
              item={item}
              onClose={() => setEditing(null)}
              onCorrected={(corrected) => {
                setEditing(null);
                setState({ status: "ready", entry: corrected });
              }}
            />
          ) : (
            <ItemCard key={item.id} item={item} onCorrect={() => setEditing(item.id)} />
          ),
        )}
        <ErrorText>{error}</ErrorText>
        {entry.status === "analyzed" && entry.items.length > 0 && <Button label="Confirmar" busy={busy} onPress={confirm} />}
        <LinkButton label="Registrar outra refeição" onPress={onDone} />
      </>
    );
  }

  return (
    <Screen>
      <Title>Estimativa da refeição</Title>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && state.error.status !== 404 && <ErrorView error={state.error} onRetry={refresh} />}
      {state.status === "error" && state.error.status === 404 && (
        <>
          <ErrorText>{mealErrorMessage(state.error)}</ErrorText>
          <LinkButton label="Registrar outra refeição" onPress={onDone} />
        </>
      )}
      {state.status === "ready" && renderEntry(state.entry)}
    </Screen>
  );
}
