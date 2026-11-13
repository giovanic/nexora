import { router } from "expo-router";
import { DoneStep } from "../../features/onboarding/DoneStep";

export default function Done() {
  return <DoneStep onOpenCamera={() => router.replace("/home")} />;
}
