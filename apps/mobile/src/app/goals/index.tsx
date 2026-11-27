import { router } from "expo-router";
import { GoalsTodayScreen } from "../../features/goals/GoalsTodayScreen";
import { api } from "../../shared/api";
import { useRefreshOnFocus } from "../../shared/useRefreshOnFocus";

export default function Goals() {
  const refreshKey = useRefreshOnFocus();
  return (
    <GoalsTodayScreen
      api={api}
      refreshKey={refreshKey}
      onNew={() => router.push("/goals/new")}
      onOpen={(id) => router.push({ pathname: "/goals/[id]", params: { id } })}
      onHistory={() => router.push("/goals/history")}
    />
  );
}
