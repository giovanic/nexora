import { Body, Button, Screen, Title } from "../../shared/ui";

// Until Phase 03 the camera has no screen: this is where "Pronto" leads.
export function ComingSoonScreen({ onOpenSettings }: { onOpenSettings: () => void }) {
  return (
    <Screen>
      <Title>Em breve</Title>
      <Body>A câmera chega em breve. Por enquanto, você já pode ajustar o seu perfil e os seus consentimentos.</Body>
      <Button label="Configurações" variant="secondary" onPress={onOpenSettings} />
    </Screen>
  );
}
