import { Body, Button, Screen, Title } from "../../shared/ui";

export function DoneStep({ onOpenCamera }: { onOpenCamera: () => void }) {
  return (
    <Screen>
      <Title>Pronto</Title>
      <Body>Tudo certo por aqui. Quando quiser, registre sua primeira refeição pela câmera.</Body>
      <Button label="Abrir a câmera" onPress={onOpenCamera} />
    </Screen>
  );
}
