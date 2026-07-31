import dayjs from "dayjs";
import customParseFormat from "dayjs/plugin/customParseFormat";
import timezone from "dayjs/plugin/timezone";
import utc from "dayjs/plugin/utc";

dayjs.extend(utc);
dayjs.extend(customParseFormat);
dayjs.extend(timezone);

const DATE_ONLY = "YYYY-MM-DD";

export function nowIso(): string {
  return dayjs().toISOString();
}

export function nowMs(): number {
  return dayjs().valueOf();
}

export function todayDateOnly(): string {
  return dayjs().format(DATE_ONLY);
}

export function parseMs(value: dayjs.ConfigType): number {
  return dayjs(value).valueOf();
}

export function addMsFromNow(ms: number): string {
  return dayjs().add(ms, "millisecond").toISOString();
}

export function addSecondsFromNow(seconds: number): string {
  return dayjs().add(seconds, "second").toISOString();
}

export function isValidDateOnly(value: unknown): value is string {
  const text = String(value ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;
  return dayjs.utc(text, DATE_ONLY, true).isValid();
}

export function toDateOnly(value: unknown) {
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

export function formatLedgerDate(value: unknown) {
  const dateOnly = toDateOnly(value);
  if (!dateOnly) return "Unknown date";

  return dayjs.tz(`${dateOnly}T12:00:00`, "Asia/Kolkata").format("D MMM YYYY");
}

export function formatDateTimeInTz(
  value: dayjs.ConfigType = dayjs(),
  timeZone = "Asia/Kolkata",
) {
  return dayjs(value).tz(timeZone).format("D MMM YYYY, h:mm a");
}

export function formatLocalDateTime(value: dayjs.ConfigType) {
  return dayjs(value).format("D MMM YYYY, h:mm:ss a");
}

export function formatLongDate(
  value: dayjs.ConfigType = dayjs(),
  timeZone = "Asia/Kolkata",
) {
  return dayjs(value).tz(timeZone).format("dddd, D MMMM YYYY");
}

export function shiftDateOnly(dateOnly: string, days: number) {
  return dayjs.utc(`${dateOnly}T12:00:00`).add(days, "day").format(DATE_ONLY);
}

export function todayInTimezone(timeZone: string) {
  return dayjs().tz(timeZone).format(DATE_ONLY);
}

export function isWithinLastDays(
  value: dayjs.ConfigType,
  days: number,
  relativeTo: dayjs.ConfigType = dayjs(),
) {
  return dayjs(relativeTo).diff(dayjs(value), "day") < days;
}
