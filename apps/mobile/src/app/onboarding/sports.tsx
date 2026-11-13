import { router } from "expo-router";
import { SportsStep } from "../../features/onboarding/SportsStep";
import { api } from "../../shared/api";

export default function Sports() {
  return (
    <SportsStep
      api={api}
      onNext={() => router.replace("/onboarding/done")}
      onConsentRequired={() => router.replace("/onboarding/consent")}
    />
  );
}
