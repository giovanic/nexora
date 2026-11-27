import { router, useLocalSearchParams } from "expo-router";
import { GoalDetailScreen } from "../../features/goals/GoalDetailScreen";
import { api } from "../../shared/api";

export default function GoalDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <GoalDetailScreen api={api} goalId={id} onDeleted={() => router.replace("/goals")} />;
}
