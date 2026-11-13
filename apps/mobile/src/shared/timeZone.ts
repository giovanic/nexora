// The device time zone, by Intl (no extra package). Returns null when Intl
// cannot answer, so sign up shows a clear error instead of guessing a zone.
export function deviceTimeZone(): string | null {
  try {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return typeof zone === "string" && zone.length > 0 ? zone : null;
  } catch {
    return null;
  }
}
