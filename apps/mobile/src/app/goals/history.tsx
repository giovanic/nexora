import { router } from "expo-router";
import { GoalHistoryScreen } from "../../features/goals/GoalHistoryScreen";
import { api } from "../../shared/api";
import { useRefreshOnFocus } from "../../shared/useRefreshOnFocus";

export default function GoalHistory() {
  const refreshKey = useRefreshOnFocus();
  return <GoalHistoryScreen api={api} refreshKey={refreshKey} onOpen={(id) => router.push({ pathname: "/goals/[id]", params: { id } })} />;
}
