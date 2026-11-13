import { router } from "expo-router";
import { SettingsScreen } from "../features/settings/SettingsScreen";
import { api } from "../shared/api";

const toConsent = () => router.replace("/onboarding/consent");

export default function Settings() {
  return (
    <SettingsScreen
      api={api}
      webUrl={process.env.EXPO_PUBLIC_APP_WEB_URL}
      onSignedOut={() => router.replace("/sign-in")}
      onConsentRequired={toConsent}
      onHealthRevoked={toConsent}
    />
  );
}
