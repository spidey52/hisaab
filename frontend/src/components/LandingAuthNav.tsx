import { useEffect, useState } from "react";
import { Link } from "@tanstack/react-router";
import {
  apiFetch,
  clearSessionToken,
  isAuthenticatedClient,
} from "@/lib/api-client";

export function LandingAuthNav() {
  const [authed, setAuthed] = useState(false);

  useEffect(() => {
    setAuthed(isAuthenticatedClient());
  }, []);

  return (
    <nav className="landing-nav" aria-label="Main navigation">
      <a href="#how-it-works">How it works</a>
      <a href="#safety">Safety</a>
      {authed
        ? (
          <>
            <Link className="button button-secondary compact" to="/app">
              Open Hisaab
            </Link>
            <button
              className="quiet-link"
              type="button"
              onClick={async () => {
                await apiFetch("/api/auth/logout", { method: "POST" });
                clearSessionToken();
                window.location.href = "/";
              }}
            >
              Sign out
            </button>
          </>
        )
        : (
          <Link className="button button-primary compact" to="/login">
            Sign in
          </Link>
        )}
    </nav>
  );
}
