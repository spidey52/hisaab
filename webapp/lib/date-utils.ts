export function isValidDateOnly(value: unknown): value is string {
  const text = String(value ?? "").trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;

  const [year, month, day] = text.split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return (
    parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day
  );
}

export function toDateOnly(value: unknown) {
  if (value instanceof Date && Number.isFinite(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }

  const text = String(value ?? "").trim();
  const dateOnly = text.match(/^\d{4}-\d{2}-\d{2}/)?.[0];
  if (dateOnly && isValidDateOnly(dateOnly)) return dateOnly;

  const parsed = new Date(text);
  return Number.isFinite(parsed.getTime())
    ? parsed.toISOString().slice(0, 10)
    : "";
}

export function formatLedgerDate(value: unknown) {
  const dateOnly = toDateOnly(value);
  if (!dateOnly) return "Unknown date";

  return new Intl.DateTimeFormat("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "Asia/Kolkata",
  }).format(new Date(`${dateOnly}T12:00:00+05:30`));
}
