import config from "../../../app.json";

describe("app.json", () => {
  it("keeps pending photos out of Android backups", () => {
    expect(config.expo.android.allowBackup).toBe(false);
  });

  it("stays light until there is a dark theme", () => {
    expect(config.expo.userInterfaceStyle).toBe("light");
  });
});
