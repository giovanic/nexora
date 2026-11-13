import { Linking } from "react-native";
import type { Api } from "../../shared/api";
import { Screen, Title } from "../../shared/ui";
import { AccountSection } from "./AccountSection";
import { ConsentsSection } from "./ConsentsSection";
import { ProfileSection } from "./ProfileSection";
import { SessionsSection } from "./SessionsSection";
import { SportsSection } from "./SportsSection";

type Props = {
  api: Api;
  webUrl?: string;
  openUrl?: (url: string) => void;
  onSignedOut: () => void;
  // Opens the consent step, so the person can grant health_data (nothing is redirected on its own).
  onOpenConsent: () => void;
  // health_data was revoked: its data is erased, the account stays, back to the consent step.
  onHealthRevoked: () => void;
};

const defaultOpenUrl = (url: string) => {
  Linking.openURL(url).catch(() => {});
};

export function SettingsScreen({ api, webUrl, openUrl = defaultOpenUrl, onSignedOut, onOpenConsent, onHealthRevoked }: Props) {
  return (
    <Screen>
      <Title>Configurações</Title>
      <ProfileSection api={api} onOpenConsent={onOpenConsent} />
      <SportsSection api={api} onOpenConsent={onOpenConsent} />
      <ConsentsSection api={api} onHealthRevoked={onHealthRevoked} />
      <SessionsSection api={api} />
      <AccountSection api={api} webUrl={webUrl} openUrl={openUrl} onSignedOut={onSignedOut} />
    </Screen>
  );
}
