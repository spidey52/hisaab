import dayjs, { type Dayjs } from "dayjs";
import customParseFormat from "dayjs/plugin/customParseFormat";
import utc from "dayjs/plugin/utc";

dayjs.extend(utc);
dayjs.extend(customParseFormat);

const DATE_ONLY = "YYYY-MM-DD";

export function now(): Dayjs {
  return dayjs();
}

/** Current instant as a JS Date (for Drizzle timestamptz columns). */
export function nowDate(): Date {
  return dayjs().toDate();
}

export function nowIso(): string {
  return dayjs().toISOString();
}

export function todayDateOnly(): string {
  return dayjs().format(DATE_ONLY);
}

export function toJsDate(value?: dayjs.ConfigType): Date {
  return dayjs(value).toDate();
}

export function addDuration(
  amount: number,
  unit: dayjs.ManipulateType,
  from: dayjs.ConfigType = dayjs(),
): Date {
  return dayjs(from).add(amount, unit).toDate();
}

export function subtractDuration(
  amount: number,
  unit: dayjs.ManipulateType,
  from: dayjs.ConfigType = dayjs(),
): Date {
  return dayjs(from).subtract(amount, unit).toDate();
}

export function isValidDateOnly(value: unknown): value is string {
  const text = String(value ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;
  return dayjs.utc(text, DATE_ONLY, true).isValid();
}

export function toDateOnly(value: unknown): string {
  if (dayjs.isDayjs(value) || value instanceof Date) {
    const parsed = dayjs(value);
    return parsed.isValid() ? parsed.format(DATE_ONLY) : "";
  }

  const text = String(value ?? "").trim();
  const dateOnly = text.match(/^\d{4}-\d{2}-\d{2}/)?.[0];
  if (dateOnly && isValidDateOnly(dateOnly)) return dateOnly;

  const parsed = dayjs(text);
  return parsed.isValid() ? parsed.format(DATE_ONLY) : "";
}
