import { useCallback, useEffect, useState } from "react";
import type { Api, Failure, FoodEntry } from "../../shared/api";
import { Body, Button, EmptyView, ErrorText, ErrorView, LoadingView, Screen, Subtitle, Title } from "../../shared/ui";
import { dayText, kcalRange } from "./formatRange";
import { mealErrorMessage } from "./mealMessages";

type Props = { api: Api; onOpen: (entryId: string) => void; onNewMeal: () => void };

type State =
  | { status: "loading" }
  | { status: "error"; error: Failure }
  | { status: "ready"; entries: FoodEntry[]; cursor: string | null };

function timeText(iso: string): string {
  const date = new Date(iso);
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function summary(entry: FoodEntry): string {
  if (entry.status === "processing") return "Analisando a foto";
  if (entry.status === "pending") return "Aguardando a foto chegar";
  if (entry.status === "failed") return "A análise não terminou";
  if (entry.result_code === "no_food") return "Não encontramos comida na foto";
  if (entry.result_code === "unreadable") return "Não foi possível ler a foto";
  const range = kcalRange(entry.calories_min, entry.calories_max);
  if (!range) return "Sem estimativa";
  return entry.estimate_partial ? `${range} · estimativa parcial` : range;
}

// Meals grouped by local date, newest first, by cursor. Each meal shows only its own range.
export function MealHistoryScreen({ api, onOpen, onNewMeal }: Props) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [more, setMore] = useState<{ busy: boolean; error: string | null }>({ busy: false, error: null });
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    api.listFoodEntries().then((result) => {
      if (!live) return;
      setState(result.ok ? { status: "ready", entries: result.data.items, cursor: result.data.next_cursor } : { status: "error", error: result });
    });
    return () => {
      live = false;
    };
  }, [api, tick]);

  const reload = useCallback(() => {
    setState({ status: "loading" });
    setTick((value) => value + 1);
  }, []);

  async function loadMore(cursor: string, entries: FoodEntry[]) {
    setMore({ busy: true, error: null });
    const result = await api.listFoodEntries(cursor);
    if (!result.ok) return setMore({ busy: false, error: mealErrorMessage(result) });
    setMore({ busy: false, error: null });
    setState({ status: "ready", entries: [...entries, ...result.data.items], cursor: result.data.next_cursor });
  }

  return (
    <Screen>
      <Title>Histórico</Title>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && state.entries.length === 0 && <EmptyView>Você ainda não registrou nenhuma refeição.</EmptyView>}
      {state.status === "ready" &&
        state.entries.map((entry, index) => (
          <HistoryRow key={entry.id} entry={entry} showDay={index === 0 || state.entries[index - 1].local_date !== entry.local_date} onOpen={onOpen} />
        ))}
      {state.status === "ready" && state.cursor ? (
        <>
          <ErrorText>{more.error}</ErrorText>
          <Button label="Ver mais" variant="secondary" busy={more.busy} onPress={() => loadMore(state.cursor as string, state.entries)} />
        </>
      ) : null}
      <Button label="Registrar refeição" onPress={onNewMeal} />
    </Screen>
  );
}

function HistoryRow({ entry, showDay, onOpen }: { entry: FoodEntry; showDay: boolean; onOpen: (id: string) => void }) {
  return (
    <>
      {showDay ? <Subtitle>{dayText(entry.local_date)}</Subtitle> : null}
      <Body>{summary(entry)}</Body>
      <Button label={`Abrir refeição das ${timeText(entry.meal_at)}`} variant="secondary" onPress={() => onOpen(entry.id)} />
    </>
  );
}
