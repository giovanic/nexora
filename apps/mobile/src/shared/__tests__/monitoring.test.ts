import type { ErrorEvent } from "@sentry/react-native";
import { initMonitoring, scrubEvent } from "../monitoring";

jest.mock("@sentry/react-native", () => ({ init: jest.fn() }));

describe("initMonitoring", () => {
  it("does not start without a DSN", () => {
    const init = jest.fn();

    expect(initMonitoring(undefined, init)).toBe(false);
    expect(initMonitoring("", init)).toBe(false);
    expect(init).not.toHaveBeenCalled();
  });

  it("starts with personal data collection off", () => {
    const init = jest.fn();

    expect(initMonitoring("https://key@sentry.test/1", init)).toBe(true);

    const options = init.mock.calls[0][0];
    expect(options.dsn).toBe("https://key@sentry.test/1");
    expect(options.sendDefaultPii).toBe(false);
    expect(options.beforeSend).toBe(scrubEvent);
    expect(options.beforeBreadcrumb()).toBeNull();
    // The native SDK sends its crash reports without passing through beforeSend.
    expect(options.enableNativeCrashHandling).toBe(false);
  });
});

describe("scrubEvent", () => {
  it("removes the user, breadcrumbs, exception message and request details", () => {
    const event = {
      type: undefined,
      user: { email: "person@example.test" },
      breadcrumbs: [{ message: "person@example.test" }],
      exception: { values: [{ type: "Error", value: "failed for person@example.test" }] },
      request: { url: "app://path?token=tok-secret", query_string: "token=tok-secret" },
    } as unknown as ErrorEvent;

    const serialized = JSON.stringify(scrubEvent(event));

    expect(serialized).not.toContain("person@example.test");
    expect(serialized).not.toContain("tok-secret");
    expect(serialized).toContain('"type":"Error"');
  });

  it("keeps only known fields", () => {
    const event = {
      type: undefined,
      extra: { meal: "rice-secret-item" },
      tags: { email: "person@example.test" },
      contexts: { meal: { items: "rice-secret-item" } },
      fingerprint: ["person@example.test"],
      transaction: "/users/person@example.test",
      exception: {
        values: [
          {
            type: "Error",
            mechanism: { type: "generic", data: { detail: "rice-secret-item" } },
            stacktrace: {
              frames: [{ filename: "app.js", function: "run", lineno: 1, vars: { token: "tok-secret" } }],
            },
          },
        ],
      },
    } as unknown as ErrorEvent;

    const serialized = JSON.stringify(scrubEvent(event));

    expect(serialized).not.toContain("person@example.test");
    expect(serialized).not.toContain("rice-secret-item");
    expect(serialized).not.toContain("tok-secret");
    expect(serialized).toContain('"filename":"app.js"');
  });
});
