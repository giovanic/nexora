import { useCallback, useEffect, useState } from "react";
import { View } from "react-native";
import type { Api, Failure, Goal, GoalList } from "../../shared/api";
import { Body, Button, Choice, EmptyView, ErrorView, InfoText, LinkButton, LoadingView, Screen, Title } from "../../shared/ui";
import { GOAL_TYPE_LABELS, goalErrorMessage, goalTexts, isGoalType } from "./goalMessages";

type Props = { api: Api; onNew: () => void; onOpen: (goalId: string) => void };

type State = { status: "loading" } | { status: "error"; error: Failure } | { status: "ready"; list: GoalList };
type Day = "today" | "yesterday";
type Notice = { text: string; retry: (() => void) | null };

// Everything shown comes from the API: the two dates, what is done and where it came from.
// A tap changes nothing on screen until the answer arrives.
export function GoalsTodayScreen({ api, onNew, onOpen }: Props) {
  const [state, setState] = useState<State>({ status: "loading" });
  const [day, setDay] = useState<Day>("today");
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<Notice | null>(null);
  const [sources, setSources] = useState<Record<string, string[]>>({});

  const load = useCallback(
    async (quiet: boolean) => {
      if (!quiet) setState({ status: "loading" });
      const result = await api.listGoals();
      if (result.ok) {
        setSources({});
        setState({ status: "ready", list: result.data });
      } else if (!quiet) {
        setState({ status: "error", error: result });
      }
    },
    [api],
  );

  useEffect(() => {
    let live = true;
    api.listGoals().then((result) => {
      if (!live) return;
      setState(result.ok ? { status: "ready", list: result.data } : { status: "error", error: result });
    });
    return () => {
      live = false;
    };
  }, [api]);

  async function toggle(goal: Goal, list: GoalList, chosen: Day, done: boolean) {
    const localDate = chosen === "today" ? list.today_local_date : list.yesterday_local_date;
    setBusy(goal.id);
    setNotice(null);
    const result = await (done ? api.uncheckGoal(goal.id, localDate) : api.checkInGoal(goal.id, localDate));
    setBusy(null);

    if (!result.ok) {
      setNotice({ text: goalErrorMessage(result), retry: result.detail === "outside_window" ? null : () => void toggle(goal, list, chosen, done) });
      // The day moved on while the screen was open: the new dates come from the API.
      if (result.detail === "outside_window" || result.code === "goal_not_active") void load(true);
      return;
    }
    const answer = result.data;
    setSources((current) => ({ ...current, [`${goal.id}:${answer.local_date}`]: answer.sources }));
    setState((current) =>
      current.status !== "ready"
        ? current
        : {
            status: "ready",
            list: {
              ...current.list,
              goals: current.list.goals.map((item) =>
                item.id !== goal.id
                  ? item
                  : {
                      ...item,
                      done_today: answer.local_date === current.list.today_local_date ? answer.done : item.done_today,
                      done_yesterday: answer.local_date === current.list.yesterday_local_date ? answer.done : item.done_yesterday,
                    },
              ),
            },
          },
    );
  }

  const goals = state.status === "ready" ? state.list.goals.filter((goal) => isGoalType(goal.goal_type) && goal.status !== "ended") : [];
  const live = [...goals.filter((goal) => goal.status === "active"), ...goals.filter((goal) => goal.status === "paused")];

  return (
    <Screen>
      <Title>Metas do dia</Title>
      {state.status === "loading" && <LoadingView />}
      {state.status === "error" && <ErrorView error={state.error} onRetry={() => void load(false)} />}
      {state.status === "ready" && live.length === 0 && <EmptyView>{goalTexts.empty}</EmptyView>}
      {state.status === "ready" && live.length > 0 && (
        <>
          <Choice kind="radio" label={goalTexts.today} selected={day === "today"} onPress={() => setDay("today")} />
          <Choice kind="radio" label={goalTexts.yesterday} selected={day === "yesterday"} onPress={() => setDay("yesterday")} />
        </>
      )}
      {state.status === "ready" &&
        live.map((goal) => (
          <GoalRow
            key={goal.id}
            goal={goal}
            list={state.list}
            day={day}
            busy={busy === goal.id}
            disabled={busy !== null}
            sources={sources[`${goal.id}:${day === "today" ? state.list.today_local_date : state.list.yesterday_local_date}`]}
            onToggle={(done) => void toggle(goal, state.list, day, done)}
            onOpen={onOpen}
          />
        ))}
      {notice && (
        <>
          <InfoText>{notice.text}</InfoText>
          {notice.retry && <Button label="Tentar de novo" variant="secondary" onPress={notice.retry} />}
        </>
      )}
      <LinkButton label="Nova meta" onPress={onNew} />
    </Screen>
  );
}

type RowProps = {
  goal: Goal;
  list: GoalList;
  day: Day;
  busy: boolean;
  disabled: boolean;
  sources: string[] | undefined;
  onToggle: (done: boolean) => void;
  onOpen: (goalId: string) => void;
};

function GoalRow({ goal, list, day, busy, disabled, sources, onToggle, onOpen }: RowProps) {
  const label = GOAL_TYPE_LABELS[goal.goal_type];
  const done = day === "today" ? goal.done_today : goal.done_yesterday;
  // A goal cannot be marked for a day before it started (string compare on ISO dates from the API).
  const beforeStart = day === "yesterday" && goal.starts_on > list.yesterday_local_date;
  const paused = goal.status === "paused";

  return (
    <View testID="goal-row" style={{ gap: 8 }}>
      <Body>{label}</Body>
      {paused ? (
        <Body>{goalTexts.paused}</Body>
      ) : (
        !beforeStart && (
          <>
            <Button label={goalTexts.done} variant={done ? "primary" : "secondary"} busy={busy} disabled={disabled} selected={done} onPress={() => onToggle(done)} />
            {done && sources?.includes("food_entry") && <InfoText>{goalTexts.completedByMeal}</InfoText>}
          </>
        )
      )}
      <LinkButton label={`Ver meta: ${label}`} onPress={() => onOpen(goal.id)} />
    </View>
  );
}
