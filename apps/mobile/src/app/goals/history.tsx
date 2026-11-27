import { GoalHistoryScreen } from "../../features/goals/GoalHistoryScreen";
import { api } from "../../shared/api";

export default function GoalHistory() {
  return <GoalHistoryScreen api={api} />;
}
