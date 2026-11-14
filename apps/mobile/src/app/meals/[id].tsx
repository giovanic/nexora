import { router, useLocalSearchParams } from "expo-router";
import { MealResultScreen } from "../../features/meals/MealResultScreen";
import { api } from "../../shared/api";

export default function MealResult() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return (
    <MealResultScreen
      api={api}
      entryId={id}
      onNewPhoto={() => router.replace("/meals")}
      onManual={() => router.replace("/meals/manual")}
      onDone={() => router.replace("/meals")}
    />
  );
}
