import { Platform } from "react-native";

type PlatformLike = { OS: string; constants?: Record<string, unknown> };

const MAX_LENGTH = 100;

// A label to tell sessions apart ("Android: google Pixel 8"). Built only from
// the platform and device model, never from a person's name, and without a new package.
export function deviceLabel(platform: PlatformLike = Platform as unknown as PlatformLike): string {
  const constants = platform.constants ?? {};
  let label: string;

  if (platform.OS === "android") {
    const model = [constants.Brand, constants.Model].filter((part): part is string => typeof part === "string" && part !== "").join(" ");
    label = model ? `Android: ${model}` : "Android";
  } else if (platform.OS === "ios") {
    label = constants.interfaceIdiom === "pad" ? "iPad" : "iPhone";
  } else {
    label = "Celular";
  }

  return label.slice(0, MAX_LENGTH);
}
