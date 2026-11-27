import { router } from "expo-router";
import { GoalsTodayScreen } from "../../features/goals/GoalsTodayScreen";
import { api } from "../../shared/api";

export default function Goals() {
  return (
    <GoalsTodayScreen
      api={api}
      onNew={() => router.push("/goals/new")}
      onOpen={(id) => router.push({ pathname: "/goals/[id]", params: { id } })}
      onHistory={() => router.push("/goals/history")}
    />
  );
}
