import type { ErrorEvent } from "@sentry/react";
import { describe, expect, it, vi } from "vitest";
import { initMonitoring, scrubEvent } from "./monitoring";

describe("initMonitoring", () => {
  it("does not start without a DSN", () => {
    const init = vi.fn();

    expect(initMonitoring(undefined, init)).toBe(false);
    expect(initMonitoring("", init)).toBe(false);
    expect(init).not.toHaveBeenCalled();
  });

  it("starts with personal data collection off", () => {
    const init = vi.fn();

    expect(initMonitoring("https://key@sentry.test/1", init)).toBe(true);

    expect(init).toHaveBeenCalledTimes(1);
    const options = init.mock.calls[0][0];
    expect(options.dsn).toBe("https://key@sentry.test/1");
    expect(options.dataCollection.userInfo).toBe(false);
    expect(options.beforeSend).toBe(scrubEvent);
  });
});

describe("scrubEvent", () => {
  it("removes the user, breadcrumbs, exception message and request details", () => {
    const event = {
      type: undefined,
      user: { email: "person@example.test" },
      breadcrumbs: [{ message: "person@example.test" }],
      exception: { values: [{ type: "Error", value: "failed for person@example.test" }] },
      request: {
        url: "http://app.test/path?token=tok-secret",
        query_string: "token=tok-secret",
        cookies: { session: "secret" },
        headers: { Referer: "http://app.test/?token=tok-secret" },
      },
    } as unknown as ErrorEvent;

    const serialized = JSON.stringify(scrubEvent(event));

    expect(serialized).not.toContain("person@example.test");
    expect(serialized).not.toContain("tok-secret");
    expect(serialized).toContain('"type":"Error"');
  });

  it("keeps the page path without the query string", () => {
    const event = { type: undefined, request: { url: "http://app.test/path?token=tok-secret" } } as unknown as ErrorEvent;

    expect(scrubEvent(event).request?.url).toBe("http://app.test/path");
  });

  it("leaves an event without a URL intact", () => {
    const event = { type: undefined, message: "x" } as unknown as ErrorEvent;

    expect(() => scrubEvent(event)).not.toThrow();
  });
});
