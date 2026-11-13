import type { ConsentPurpose, Motivation, Sport, SportLevel } from "./api";

export const MOTIVATIONS: { value: Motivation; label: string }[] = [
  { value: "start_caring", label: "Começar a me cuidar" },
  { value: "training_consistency", label: "Ter constância nos treinos" },
  { value: "understand_food", label: "Entender minha alimentação" },
  { value: "track_progress", label: "Acompanhar minha evolução" },
];

export const SPORTS: { value: Sport; label: string }[] = [
  { value: "running", label: "Corrida" },
  { value: "walking", label: "Caminhada" },
  { value: "cycling", label: "Ciclismo" },
  { value: "strength", label: "Musculação" },
  { value: "swimming", label: "Natação" },
  { value: "other", label: "Outro" },
];

export const LEVELS: { value: SportLevel; label: string }[] = [
  { value: "beginner", label: "Iniciante" },
  { value: "intermediate", label: "Intermediário" },
  { value: "advanced", label: "Avançado" },
];

export const CONSENT_LABELS: Record<ConsentPurpose, string> = {
  health_data: "Dados de saúde",
  food_photo_ai: "Foto da refeição analisada por IA",
  strava_integration: "Integração com o Strava",
  usage_metrics: "Métricas de uso do app",
};

export const MAX_MOTIVATIONS = 4;
