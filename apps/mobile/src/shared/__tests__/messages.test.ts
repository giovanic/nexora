import { errorMessage } from "../messages";
import { jsonResponse, makeApi } from "../testing/fakes";

describe("error messages by field", () => {
  const failure = (code: string, field?: string) => ({ ok: false as const, status: 422, code, field });

  it("validation_failed names the photo size, the date or the format", () => {
    expect(errorMessage(failure("validation_failed", "byte_size"))).toMatch(/10 MB/);
    expect(errorMessage(failure("validation_failed", "meal_at"))).toMatch(/data e a hora/);
    expect(errorMessage(failure("validation_failed", "content_type"))).toMatch(/formato/);
  });

  it("validation_failed without a known field keeps the portion message", () => {
    expect(errorMessage(failure("validation_failed"))).toMatch(/entre 1 e 2000 g/);
  });

  it("unsupported_media_type cites every accepted format", () => {
    const text = errorMessage(failure("unsupported_media_type", "content_type"));
    for (const name of ["JPEG", "PNG", "WebP", "HEIC", "HEIF"]) expect(text).toContain(name);
  });

  it("has its own texts for the new codes", () => {
    expect(errorMessage({ ok: false, status: 409, code: "analysis_retry_limit" })).toMatch(/outra foto/);
    expect(errorMessage({ ok: false, status: 422, code: "not_uploaded" })).toMatch(/não está mais disponível/);
  });
});

describe("api details and item routes", () => {
  it("reads the field from details", async () => {
    const { api } = makeApi({
      "POST /api/v1/food_entries/uploads": jsonResponse(422, {
        error: { code: "validation_failed", message: "x", request_id: "r", details: [{ field: "byte_size", code: "too_large" }] },
      }),
    });
    const result = await api.startFoodUpload({ client_request_id: "a", content_type: "image/jpeg", byte_size: 1, meal_at: "2026-11-13T10:00:00Z" });
    expect(result).toMatchObject({ ok: false, code: "validation_failed", field: "byte_size" });
  });

  it("deletes a meal and adds and removes items", async () => {
    const { api, calls } = makeApi({
      "DELETE /api/v1/food_entries/e1": jsonResponse(204),
      "POST /api/v1/food_entries/e1/items": jsonResponse(201, {}),
      "DELETE /api/v1/food_entries/e1/items/i1": jsonResponse(200, {}),
    });
    expect((await api.deleteFoodEntry("e1")).ok).toBe(true);
    expect((await api.addFoodEntryItem("e1", { free_text_name: "Pão", grams_likely: 50 })).ok).toBe(true);
    expect((await api.removeFoodEntryItem("e1", "i1")).ok).toBe(true);
    expect(JSON.parse(calls[1].init.body as string)).toEqual({ free_text_name: "Pão", grams_likely: 50 });
  });
});
