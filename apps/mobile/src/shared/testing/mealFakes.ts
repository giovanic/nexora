// Test helpers for the meal screens only. Nothing here is imported by a route or a screen.
import type { components } from "@app/contracts";
import type { PendingFs } from "../../features/meals/PendingPhotos";
import type { PickResult, Picker } from "../../features/meals/devicePicker";
import type { Uploader } from "../../features/meals/UploadFlow";
import { jsonResponse } from "./fakes";

type Schemas = components["schemas"];

export const ENTRY_ID = "11111111-1111-4111-8111-111111111111";
export const ITEM_ID = "22222222-2222-4222-8222-222222222222";

export function foodItem(overrides: Partial<Schemas["FoodEntryItem"]> = {}): Schemas["FoodEntryItem"] {
  return {
    id: ITEM_ID,
    name: "Arroz branco",
    origin: "ai",
    unknown: false,
    household_measure: "3 colheres de sopa",
    source: "usda_fdc",
    own_composition: false,
    quantity_grams_min: 100,
    quantity_grams_likely: 120,
    quantity_grams_max: 150,
    calories_min: 130,
    calories_likely: 160,
    calories_max: 200,
    protein_g_min: 2,
    protein_g_likely: 3,
    protein_g_max: 4,
    carbs_g_min: 28,
    carbs_g_likely: 35,
    carbs_g_max: 44,
    fat_g_min: 0,
    fat_g_likely: 0,
    fat_g_max: 1,
    ...overrides,
  };
}

export function foodEntry(overrides: Partial<Schemas["FoodEntry"]> = {}): Schemas["FoodEntry"] {
  return {
    id: ENTRY_ID,
    status: "analyzed",
    result_code: null,
    source: "photo",
    meal_at: "2026-11-13T15:30:00Z",
    local_date: "2026-11-13",
    estimate_partial: false,
    unknown_items_count: 0,
    confidence: "medium",
    photo_url: null,
    calories_min: 420,
    calories_likely: 500,
    calories_max: 610,
    protein_g_min: 20,
    protein_g_likely: 25,
    protein_g_max: 30,
    carbs_g_min: 50,
    carbs_g_likely: 60,
    carbs_g_max: 70,
    fat_g_min: 10,
    fat_g_likely: 15,
    fat_g_max: 20,
    items: [foodItem()],
    ...overrides,
  };
}

export const NO_NUMBERS = {
  calories_min: null,
  calories_likely: null,
  calories_max: null,
  protein_g_min: null,
  protein_g_likely: null,
  protein_g_max: null,
  carbs_g_min: null,
  carbs_g_likely: null,
  carbs_g_max: null,
  fat_g_min: null,
  fat_g_likely: null,
  fat_g_max: null,
  confidence: null,
  items: [] as Schemas["FoodEntryItem"][],
};

export const uploadGrant = (overrides: Record<string, unknown> = {}, status = 201) =>
  jsonResponse(status, {
    food_entry_id: ENTRY_ID,
    status: "pending",
    upload_url: "https://storage.test/signed-secret",
    upload_headers: { "Content-Type": "image/jpeg", "Content-Length": "1000" },
    expires_at: "2026-11-13T16:00:00Z",
    ...overrides,
  });

export const analysisAccepted = () => jsonResponse(202, { food_entry_id: ENTRY_ID, status: "processing" });

// In-memory file system. `seed` plants a file the picker "produced".
export function fakeFs() {
  const files = new Map<string, number>();
  const dirs = new Set<string>();
  const fs = {
    documentDirectory: "file:///docs/",
    makeDirectoryAsync: jest.fn(async (uri: string) => {
      dirs.add(uri);
    }),
    copyAsync: jest.fn(async ({ from, to }: { from: string; to: string }) => {
      if (!files.has(from)) throw new Error("missing source");
      files.set(to, files.get(from) ?? 0);
    }),
    deleteAsync: jest.fn(async (uri: string) => {
      if (uri.endsWith("/")) {
        for (const key of [...files.keys()]) if (key.startsWith(uri)) files.delete(key);
        dirs.delete(uri);
      } else {
        files.delete(uri);
      }
    }),
    getInfoAsync: jest.fn(async (uri: string) => ({ exists: files.has(uri) || dirs.has(uri), size: files.get(uri) })),
  } satisfies PendingFs;
  return {
    fs,
    files,
    seed: (uri: string, size = 1000) => files.set(uri, size),
    pending: () => [...files.keys()].filter((key) => key.startsWith("file:///docs/pending-photos/")),
  };
}

export function fakePicker(result: PickResult): Picker & { takePhoto: jest.Mock; choosePhoto: jest.Mock } {
  return { takePhoto: jest.fn(async () => result), choosePhoto: jest.fn(async () => result) };
}

export const jpeg = (uri = "file:///cache/photo.jpg"): PickResult => ({
  kind: "photo",
  photo: { uri, mimeType: "image/jpeg", fileSize: 1000, fileName: "photo.jpg" },
});

export function fakeUploader(results: Awaited<ReturnType<Uploader["put"]>>[] = []) {
  const queue = [...results];
  const put = jest.fn(async (_url: string, _fileUri: string, _headers: Record<string, string>) => queue.shift() ?? { ok: true as const });
  return { put } satisfies Uploader & { put: jest.Mock };
}
