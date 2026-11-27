import { useCallback, useEffect, useState } from "react";
import type { Api, Failure, Goal, GoalHistoryDay, GoalStatus } from "../../shared/api";
import { Body, Button, EmptyView, ErrorText, ErrorView, LoadingView, Screen, Subtitle, Title } from "../../shared/ui";
import { dayText } from "../meals/formatRange";
import { GOAL_TYPE_LABELS, goalErrorMessage, goalTexts, isGoalType } from "./goalMessages";

type Props = { api: Api; goalId: string; onDeleted: () => void };

type State = { status: "loading" } | { status: "error"; error: Failure } | { status: "missing" } | { status: "ready"; goal: Goal };
type History = { status: "loading" } | { status: "error"; error: Failure } | { status: "ready"; items: GoalHistoryDay[]; cursor: string | null };
type Ask = "end" | "delete" | null;

export function GoalDetailScreen({ api, goalId, onDeleted }: Props) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [history, setHistory] = useState<History>({ status: "loading" });
  const [more, setMore] = useState<{ busy: boolean; error: string | null }>({ busy: false, error: null });
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [ask, setAsk] = useState<Ask>(null);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    api.listGoals().then((result) => {
      if (!live) return;
      if (!result.ok) return setState({ status: "error", error: result });
      const goal = result.data.goals.find((item) => item.id === goalId);
      setState(goal && isGoalType(goal.goal_type) ? { status: "ready", goal } : { status: "missing" });
    });
    api.goalHistory({ goalId }).then((result) => {
      if (!live) return;
      setHistory(result.ok ? { status: "ready", items: result.data.items, cursor: result.data.next_cursor } : { status: "error", error: result });
    });
    return () => {
      live = false;
    };
  }, [api, goalId, tick]);

  const reload = useCallback(() => {
    setState({ status: "loading" });
    setHistory({ status: "loading" });
    setTick((value) => value + 1);
  }, []);

  async function loadMore(cursor: string, items: GoalHistoryDay[]) {
    setMore({ busy: true, error: null });
    const result = await api.goalHistory({ goalId, cursor });
    if (!result.ok) return setMore({ busy: false, error: goalErrorMessage(result) });
    setMore({ busy: false, error: null });
    setHistory({ status: "ready", items: [...items, ...result.data.items], cursor: result.data.next_cursor });
  }

  async function change(status: GoalStatus) {
    setBusy(true);
    setMessage(null);
    const result = await api.updateGoalStatus(goalId, status);
    setBusy(false);
    setAsk(null);
    if (!result.ok) return setMessage(goalErrorMessage(result));
    setState({ status: "ready", goal: result.data });
  }

  async function remove() {
    setBusy(true);
    setMessage(null);
    const result = await api.deleteGoal(goalId);
    setBusy(false);
    // A goal already gone (404) is what the person asked for.
    if (!result.ok && result.status !== 404) {
      setAsk(null);
      return setMessage(goalErrorMessage(result));
    }
    onDeleted();
  }

  function confirm(text: string, yes: string, action: () => void) {
    return (
      <>
        <Body>{text}</Body>
        <Button label={yes} variant="danger" busy={busy} onPress={action} />
        <Button label="Cancelar" variant="secondary" disabled={busy} onPress={() => setAsk(null)} />
      </>
    );
  }

  function actions(goal: Goal) {
    if (ask === "end") return confirm(goalTexts.confirmEnd, "Sim, encerrar", () => void change("ended"));
    if (ask === "delete") return confirm(goalTexts.confirmDelete, "Sim, apagar", () => void remove());
    return (
      <>
        {goal.status === "active" && <Button label="Pausar" variant="secondary" busy={busy} onPress={() => void change("paused")} />}
        {goal.status === "paused" && <Button label="Retomar" busy={busy} onPress={() => void change("active")} />}
        {goal.status !== "ended" && <Button label="Encerrar" variant="secondary" disabled={busy} onPress={() => setAsk("end")} />}
        <Button label="Apagar" variant="secondary" disabled={busy} onPress={() => setAsk("delete")} />
      </>
    );
  }

  return (
    <Screen>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "missing" && <EmptyView>{goalTexts.notFound}</EmptyView>}
      {state.status === "ready" && (
        <>
          <Title>{GOAL_TYPE_LABELS[state.goal.goal_type]}</Title>
          {state.goal.status === "paused" && <Body>{goalTexts.paused}</Body>}
          {state.goal.status === "ended" && <Body>{goalTexts.ended}</Body>}
          {actions(state.goal)}
          <ErrorText>{message}</ErrorText>
        </>
      )}
      {state.status !== "missing" && (
        <>
          <Subtitle>Dias marcados</Subtitle>
          {history.status === "loading" && <LoadingView />}
          {history.status === "error" && <ErrorView error={history.error} onRetry={reload} />}
          {history.status === "ready" && history.items.length === 0 && <EmptyView>{goalTexts.historyEmpty}</EmptyView>}
          {history.status === "ready" && history.items.map((item) => <Body key={item.local_date}>{historyLine(item)}</Body>)}
          {history.status === "ready" && history.cursor ? (
            <>
              <ErrorText>{more.error}</ErrorText>
              <Button label="Carregar mais" variant="secondary" busy={more.busy} onPress={() => void loadMore(history.cursor as string, history.items)} />
            </>
          ) : null}
        </>
      )}
    </Screen>
  );
}

function historyLine(item: GoalHistoryDay): string {
  const day = dayText(item.local_date);
  return item.sources.includes("food_entry") ? `${day} · pela refeição registrada` : day;
}
