import { router } from "expo-router";
import { MotivationsStep } from "../../features/onboarding/MotivationsStep";
import { api } from "../../shared/api";

export default function Motivations() {
  return (
    <MotivationsStep
      api={api}
      onNext={() => router.replace("/onboarding/sports")}
      onConsentRequired={() => router.replace("/onboarding/consent")}
    />
  );
}
