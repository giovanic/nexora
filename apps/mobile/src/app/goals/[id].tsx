import { router, useLocalSearchParams } from "expo-router";
import { GoalDetailScreen } from "../../features/goals/GoalDetailScreen";
import { api } from "../../shared/api";

// Back to the screen that opened this one (the list or the history). Without a stack (deep link), go to the list.
export default function GoalDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <GoalDetailScreen api={api} goalId={id} onDeleted={() => (router.canGoBack() ? router.back() : router.replace("/goals"))} />;
}
