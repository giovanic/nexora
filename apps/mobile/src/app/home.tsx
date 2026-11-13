import { router } from "expo-router";
import { ComingSoonScreen } from "../features/onboarding/ComingSoonScreen";

export default function Home() {
  return <ComingSoonScreen onOpenSettings={() => router.push("/settings")} />;
}
