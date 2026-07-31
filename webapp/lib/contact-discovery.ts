import { normalizeOptionalPhone } from "./phone-normalization";

export const MAX_DISCOVERY_PHONES = 500;
export const MAX_DISCOVERY_REQUESTS_PER_HOUR = 10;
export const MAX_DISCOVERY_PHONES_PER_HOUR = 2_500;

export class ContactDiscoveryValidationError extends Error {}

export function normalizeDiscoveryPhones(value: unknown) {
  if (!Array.isArray(value)) {
    throw new ContactDiscoveryValidationError(
      "Send the contact phone numbers to check.",
    );
  }
  if (value.length > MAX_DISCOVERY_PHONES) {
    throw new ContactDiscoveryValidationError(
      `Check at most ${MAX_DISCOVERY_PHONES} phone numbers at a time.`,
    );
  }

  const normalized: string[] = [];
  const seen = new Set<string>();
  for (const item of value) {
    if (typeof item !== "string" || item.length > 64) continue;
    const phone = normalizeOptionalPhone(item);
    if (!phone || seen.has(phone)) continue;
    seen.add(phone);
    normalized.push(phone);
  }
  return normalized;
}

export function selectDiscoverableMatches(
  requested: readonly string[],
  candidates: readonly {
    phoneE164: string;
    contactDiscoverable: boolean;
    deleted?: boolean;
  }[],
) {
  const present = new Set(
    candidates
      .filter(
        (candidate) =>
          candidate.contactDiscoverable &&
          !candidate.deleted &&
          requested.includes(candidate.phoneE164),
      )
      .map((candidate) => candidate.phoneE164),
  );
  return requested.filter((phone) => present.has(phone));
}
