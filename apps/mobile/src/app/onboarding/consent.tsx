import { router } from "expo-router";
import { ConsentStep } from "../../features/onboarding/ConsentStep";
import { api } from "../../shared/api";

async function signOut() {
  await api.signOut();
  router.replace("/sign-in");
}

export default function Consent() {
  return <ConsentStep api={api} onGranted={() => router.replace("/onboarding/motivations")} onSignOut={signOut} />;
}
