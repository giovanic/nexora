// Presentation only: every number arrives rounded and as a range from the API.
const whole = (value: number) => String(Math.round(value));

export function kcalRange(min: number | null, max: number | null): string | null {
  if (min === null || max === null) return null;
  const low = whole(min);
  const high = whole(max);
  return low === high ? `cerca de ${low} kcal` : `cerca de ${low} a ${high} kcal`;
}

export const gramsText = (grams: number) => `cerca de ${whole(grams)} g`;

export function waitText(seconds: number): string {
  const minutes = Math.ceil(seconds / 60);
  if (minutes < 60) return `${Math.max(minutes, 1)} ${minutes <= 1 ? "minuto" : "minutos"}`;
  const hours = Math.ceil(minutes / 60);
  return `${hours} ${hours === 1 ? "hora" : "horas"}`;
}

export const dayText = (localDate: string) => localDate.split("-").reverse().join("/");
