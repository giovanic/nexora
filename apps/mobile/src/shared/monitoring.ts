import * as Sentry from "@sentry/react-native";
import type { ErrorEvent, ReactNativeOptions } from "@sentry/react-native";

// Last check before an event leaves the device. The report keeps the error type
// and stack, never data about a person, as an error message can carry user data.
export function scrubEvent(event: ErrorEvent): ErrorEvent {
  delete event.user;
  delete event.breadcrumbs;
  delete event.message;
  delete event.extra;
  delete event.tags;
  delete event.contexts;
  delete event.fingerprint;
  delete event.transaction;
  delete event.request;

  event.exception?.values?.forEach((exception) => {
    delete exception.value;
    delete exception.mechanism?.data;
    exception.stacktrace?.frames?.forEach((frame) => {
      delete frame.vars;
    });
  });

  return event;
}

type Init = (options: ReactNativeOptions) => unknown;

// Stays inactive without a DSN, so tests and CI never send anything.
export function initMonitoring(dsn: string | undefined, init: Init = Sentry.init): boolean {
  if (!dsn) return false;

  init({
    dsn,
    sendDefaultPii: false,
    // The native SDK sends its crash reports without passing through beforeSend.
    enableNativeCrashHandling: false,
    beforeSend: scrubEvent,
    beforeBreadcrumb: () => null,
  });

  return true;
}
