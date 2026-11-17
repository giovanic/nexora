import type { Failure } from "../../shared/api";
import { errorMessage } from "../../shared/messages";
import { waitText } from "./formatRange";

export const NO_FOOD_MESSAGE = "Não encontramos comida nesta foto. Você pode tirar outra foto ou registrar sem foto.";
export const UNREADABLE_MESSAGE = "Não conseguimos ler esta foto. Tente outra, com mais luz e a comida à vista.";

// Meal screens know a few answers better than the generic mapping does.
export function mealErrorMessage(failure: Failure): string {
  if (failure.status === 429 && failure.code === "analysis_quota_exceeded") {
    const when = failure.retryAfter ? `O limite volta em cerca de ${waitText(failure.retryAfter)}.` : "O limite volta à meia-noite.";
    return `Você já enviou o máximo de fotos para análise hoje. ${when} Enquanto isso, você pode registrar sem foto.`;
  }
  if (failure.status === 404) return "Não encontramos esta refeição. Ela pode ter sido excluída.";
  return errorMessage(failure);
}
