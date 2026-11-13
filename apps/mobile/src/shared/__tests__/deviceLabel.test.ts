import { deviceLabel } from "../deviceLabel";

describe("deviceLabel", () => {
  it("builds it from the Android brand and model", () => {
    expect(deviceLabel({ OS: "android", constants: { Brand: "google", Model: "Pixel 8" } })).toBe("Android: google Pixel 8");
  });

  it("uses the idiom on iOS", () => {
    expect(deviceLabel({ OS: "ios", constants: { interfaceIdiom: "pad" } })).toBe("iPad");
    expect(deviceLabel({ OS: "ios", constants: { interfaceIdiom: "phone" } })).toBe("iPhone");
  });

  it("falls back to the system name and stays within 100 characters", () => {
    expect(deviceLabel({ OS: "android", constants: {} })).toBe("Android");
    expect(deviceLabel({ OS: "android", constants: { Brand: "x".repeat(200), Model: "y" } }).length).toBeLessThanOrEqual(100);
  });
});
