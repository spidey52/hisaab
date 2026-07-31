import { parsePhoneNumberFromString } from "libphonenumber-js";

export function normalizeOptionalPhone(value: unknown) {
  if (typeof value !== "string" || !value.trim()) return null;
  const parsed = parsePhoneNumberFromString(value.trim(), "IN");
  return parsed?.isValid() ? parsed.number : null;
}
