import { router } from "expo-router";
import { NewGoalScreen } from "../../features/goals/NewGoalScreen";
import { api } from "../../shared/api";

// Back to the screen that opened this one; the list reloads on focus. Without a stack (deep link), go to the list.
export default function NewGoal() {
  return <NewGoalScreen api={api} onCreated={() => (router.canGoBack() ? router.back() : router.replace("/goals"))} />;
}
