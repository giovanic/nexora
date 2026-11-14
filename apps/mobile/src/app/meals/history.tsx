import { router } from "expo-router";
import { MealHistoryScreen } from "../../features/meals/MealHistoryScreen";
import { api } from "../../shared/api";

export default function History() {
  return (
    <MealHistoryScreen
      api={api}
      onOpen={(id) => router.push({ pathname: "/meals/[id]", params: { id } })}
      onNewMeal={() => router.replace("/meals")}
    />
  );
}
