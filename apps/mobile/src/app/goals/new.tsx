import { router } from "expo-router";
import { NewGoalScreen } from "../../features/goals/NewGoalScreen";
import { api } from "../../shared/api";

export default function NewGoal() {
  return <NewGoalScreen api={api} onCreated={() => router.replace("/goals")} />;
}
