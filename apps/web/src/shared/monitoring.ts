import * as Sentry from "@sentry/react";
import type { ErrorEvent } from "@sentry/react";

// Last check before an event leaves the browser. The report keeps the error type
// and stack, never data about a person, as an error message can carry user data.
export function scrubEvent(event: ErrorEvent): ErrorEvent {
  delete event.user;
  delete event.breadcrumbs;
  delete event.message;

  event.exception?.values?.forEach((exception) => {
    delete exception.value;
  });

  if (event.request) {
    event.request = event.request.url ? { url: event.request.url.split(/[?#]/)[0] } : {};
  }

  return event;
}

type Init = (options: Sentry.BrowserOptions) => unknown;

// Stays inactive without a DSN, so tests and CI never send anything.
export function initMonitoring(dsn: string | undefined, init: Init = Sentry.init): boolean {
  if (!dsn) return false;

  init({
    dsn,
    beforeSend: scrubEvent,
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
    },
  });

  return true;
}
