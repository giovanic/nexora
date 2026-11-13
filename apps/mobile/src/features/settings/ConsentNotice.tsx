import { Body, Button } from "../../shared/ui";

// Shown in place of a health section while health_data is not granted. Nothing is
// forced: the rest of Settings keeps working, and the person can grant it when they wish.
export function ConsentNotice({ onOpenConsent }: { onOpenConsent: () => void }) {
  return (
    <>
      <Body>Esta parte depende do consentimento de dados de saúde. Você pode dá-lo quando quiser.</Body>
      <Button label="Dar consentimento de dados de saúde" variant="secondary" onPress={onOpenConsent} />
    </>
  );
}
