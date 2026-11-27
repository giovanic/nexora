import type { Goal, GoalList } from "../api";

export const TODAY = "2026-11-26";
export const YESTERDAY = "2026-11-25";
export const MEALS_ID = "11111111-1111-4111-8111-111111111111";
export const WATER_ID = "22222222-2222-4222-8222-222222222222";
export const SLEEP_ID = "33333333-3333-4333-8333-333333333333";

export const goal = (overrides: Partial<Goal> = {}): Goal => ({
  id: MEALS_ID,
  goal_type: "log_meals",
  status: "active",
  starts_on: "2026-11-01",
  ends_on: null,
  done_today: false,
  done_yesterday: false,
  ...overrides,
});

export const goalList = (goals: Goal[]): GoalList => ({ today_local_date: TODAY, yesterday_local_date: YESTERDAY, goals });

export const goalDay = (overrides: Record<string, unknown> = {}) => ({
  goal_id: MEALS_ID,
  local_date: TODAY,
  done: true,
  sources: ["manual"],
  ...overrides,
});

export const outsideWindow = { error: { code: "validation_failed", message: "x", request_id: "r", details: [{ field: "local_date", code: "outside_window" }] } };
