import type { Failure, GoalType } from "../../shared/api";
import { errorMessage } from "../../shared/messages";

export const GOAL_TYPE_CODES: readonly GoalType[] = ["log_meals", "include_fruits_vegetables", "drink_water", "sleep_routine", "planned_workout"];

export const GOAL_TYPE_LABELS: Record<GoalType, string> = {
  log_meals: "Registrar as refeições do dia",
  include_fruits_vegetables: "Incluir frutas ou vegetais",
  drink_water: "Beber água ao longo do dia",
  sleep_routine: "Dormir no horário que escolhi",
  planned_workout: "Fazer o treino planejado",
};

export const goalTexts = {
  done: "Feito",
  today: "Hoje",
  yesterday: "Ontem",
  empty: "Escolha um hábito para acompanhar.",
  paused: "Pausada. Retome quando quiser.",
  ended: "Meta encerrada.",
  endedMarker: "Encerrada",
  completedByMeal: "Cumprida pela refeição registrada.",
  confirmEnd: "Encerrar esta meta? O histórico continua disponível.",
  confirmDelete: "Apagar esta meta e o histórico dela? Isso não pode ser desfeito.",
  historyEmpty: "Os dias marcados aparecem aqui.",
  allCreated: "Você já acompanha todos os hábitos disponíveis.",
  notFound: "Não encontramos esta meta. Ela pode ter sido apagada.",
} as const;

// Unknown codes are never shown: the closed list lives here, not in what the server sends.
export function isGoalType(code: string): code is GoalType {
  return (GOAL_TYPE_CODES as readonly string[]).includes(code);
}

// The API puts these answers in error.details[0].code, under validation_failed.
export function goalErrorMessage(failure: Failure): string {
  if (failure.detail === "outside_window") return "Só dá para marcar hoje ou ontem.";
  if (failure.detail === "unsupported_goal_type") return "Esse tipo de meta não está disponível.";
  if (failure.code === "goal_not_active") return "Esta meta está pausada. Retome para marcar.";
  return errorMessage(failure);
}
