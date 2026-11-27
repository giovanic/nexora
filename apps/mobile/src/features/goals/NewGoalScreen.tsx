import { useCallback, useEffect, useState } from "react";
import type { Api, Failure, GoalType } from "../../shared/api";
import { Button, EmptyView, ErrorText, ErrorView, LoadingView, Screen, Subtitle, Title } from "../../shared/ui";
import { GOAL_TYPE_LABELS, goalErrorMessage, goalTexts, isGoalType } from "./goalMessages";

type Props = { api: Api; onCreated: () => void };

type State = { status: "loading" } | { status: "error"; error: Failure } | { status: "ready"; types: GoalType[] };

// Only the known types that the person does not already have (active or paused).
export function NewGoalScreen({ api, onCreated }: Props) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let live = true;
    Promise.all([api.listGoalTypes(), api.listGoals()]).then(([types, goals]) => {
      if (!live) return;
      if (!types.ok) return setState({ status: "error", error: types });
      if (!goals.ok) return setState({ status: "error", error: goals });
      const owned = new Set(goals.data.goals.filter((goal) => goal.status !== "ended").map((goal) => goal.goal_type));
      setState({ status: "ready", types: types.data.goal_types.filter((code) => isGoalType(code) && !owned.has(code)) });
    });
    return () => {
      live = false;
    };
  }, [api, tick]);

  const reload = useCallback(() => {
    setState({ status: "loading" });
    setTick((value) => value + 1);
  }, []);

  async function create(code: GoalType) {
    setBusy(code);
    setMessage(null);
    const result = await api.createGoal(code);
    setBusy(null);
    if (!result.ok) return setMessage(goalErrorMessage(result));
    onCreated();
  }

  return (
    <Screen>
      <Title>Nova meta</Title>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={reload} />}
      {state.status === "ready" && state.types.length === 0 && <EmptyView>{goalTexts.allCreated}</EmptyView>}
      {state.status === "ready" && state.types.length > 0 && <Subtitle>Escolha um hábito</Subtitle>}
      {state.status === "ready" &&
        state.types.map((code) => (
          <Button key={code} label={GOAL_TYPE_LABELS[code]} variant="secondary" busy={busy === code} disabled={busy !== null} onPress={() => void create(code)} />
        ))}
      <ErrorText>{message}</ErrorText>
    </Screen>
  );
}
