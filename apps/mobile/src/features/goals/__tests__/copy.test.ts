import { GOAL_TYPE_CODES, GOAL_TYPE_LABELS, goalErrorMessage, goalTexts } from "../goalMessages";

describe("goal copy", () => {
  it("every allowed type has a label", () => {
    expect(GOAL_TYPE_CODES).toEqual(["log_meals", "include_fruits_vegetables", "drink_water", "sleep_routine", "planned_workout"]);
    for (const code of GOAL_TYPE_CODES) expect(GOAL_TYPE_LABELS[code]).toBeTruthy();
  });

  it("no text uses an exclamation mark", () => {
    const texts = [
      ...Object.values(GOAL_TYPE_LABELS),
      ...Object.values(goalTexts),
      goalErrorMessage({ ok: false, status: 422, code: "validation_failed", field: "local_date", detail: "outside_window" }),
      goalErrorMessage({ ok: false, status: 409, code: "goal_not_active" }),
      goalErrorMessage({ ok: false, status: 422, code: "validation_failed", field: "goal_type", detail: "unsupported_goal_type" }),
      goalErrorMessage({ ok: false, status: 0, code: "network_error" }),
    ];
    for (const text of texts) expect(text).not.toContain("!");
  });
});
