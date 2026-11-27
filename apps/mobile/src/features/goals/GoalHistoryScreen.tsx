import { useCallback, useEffect, useState } from "react";
import type { Api, Failure, GoalHistoryDay } from "../../shared/api";
import { Button, EmptyView, ErrorText, ErrorView, LinkButton, LoadingView, Screen, Title } from "../../shared/ui";
import { dayText } from "../meals/formatRange";
import { GOAL_TYPE_LABELS, goalErrorMessage, goalTexts, isGoalType } from "./goalMessages";

// refreshKey: a new value reloads the list without the loading state (the screen regained focus).
type Props = { api: Api; onOpen: (goalId: string) => void; refreshKey?: number };

type State = { status: "loading" } | { status: "error"; error: Failure } | { status: "ready"; items: GoalHistoryDay[]; cursor: string | null };

// Completed days of every goal, ended ones included, newest first. Missed days are never listed.
export function GoalHistoryScreen({ api, onOpen, refreshKey = 0 }: Props) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [more, setMore] = useState<{ busy: boolean; error: string | null }>({ busy: false, error: null });
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    api.goalHistory().then((result) => {
      if (!live) return;
      // A silent reload that fails keeps what is already on screen.
      setState((current) =>
        result.ok
          ? { status: "ready", items: result.data.items, cursor: result.data.next_cursor }
          : current.status === "ready"
            ? current
            : { status: "error", error: result },
      );
    });
    return () => {
      live = false;
    };
  }, [api, tick, refreshKey]);

  const reload = useCallback(() => {
    setState({ status: "loading" });
    setTick((value) => value + 1);
  }, []);

  async function loadMore(cursor: string, items: GoalHistoryDay[]) {
    setMore({ busy: true, error: null });
    const result = await api.goalHistory({ cursor });
    if (!result.ok) return setMore({ busy: false, error: goalErrorMessage(result) });
    setMore({ busy: false, error: null });
    setState({ status: "ready", items: [...items, ...result.data.items], cursor: result.data.next_cursor });
  }

  const shown = state.status === "ready" ? state.items.filter((item) => isGoalType(item.goal_type)) : [];

  return (
    <Screen>
      <Title>Histórico</Title>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && shown.length === 0 && !state.cursor && <EmptyView>{goalTexts.historyEmpty}</EmptyView>}
      {shown.map((item) => (
        <LinkButton key={`${item.goal_id}:${item.local_date}`} label={line(item)} onPress={() => onOpen(item.goal_id)} />
      ))}
      {state.status === "ready" && state.cursor ? (
        <>
          <ErrorText>{more.error}</ErrorText>
          <Button label="Carregar mais" variant="secondary" busy={more.busy} onPress={() => void loadMore(state.cursor as string, state.items)} />
        </>
      ) : null}
    </Screen>
  );
}

function line(item: GoalHistoryDay): string {
  const parts = [GOAL_TYPE_LABELS[item.goal_type], dayText(item.local_date)];
  if (item.goal_status === "ended") parts.push(goalTexts.endedMarker);
  return parts.join(" · ");
}
