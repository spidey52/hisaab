const TOKEN_KEY = "hisaab_session_token";
const PHONE_KEY = "hisaab_session_phone";

export function apiBaseUrl() {
  const configured = (import.meta.env.VITE_API_BASE_URL ?? "").trim();
  return configured.replace(/\/+$/, "") || "http://localhost:3001";
}

export function getSessionToken(): string | null {
  try {
    return sessionStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function getSessionPhone(): string | null {
  try {
    return sessionStorage.getItem(PHONE_KEY);
  } catch {
    return null;
  }
}

export function setSessionToken(token: string, phoneE164?: string) {
  sessionStorage.setItem(TOKEN_KEY, token);
  if (phoneE164) sessionStorage.setItem(PHONE_KEY, phoneE164);
}

export function clearSessionToken() {
  try {
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(PHONE_KEY);
  } catch {
    // ignore
  }
}

export function isAuthenticatedClient() {
  const token = getSessionToken();
  return Boolean(token && token.length >= 32);
}

/** Fetch against the Hono API with Bearer auth. Path should start with `/api/`. */
export async function apiFetch(path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  const token = getSessionToken();
  if (token) headers.set("authorization", `Bearer ${token}`);
  if (init.body && !headers.has("content-type")) {
    headers.set("content-type", "application/json");
  }
  const url = path.startsWith("http") ? path : `${apiBaseUrl()}${path}`;
  return fetch(url, { ...init, headers });
}
