import { ArrowRight } from "lucide-react";
import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { isAuthenticatedClient } from "@/lib/api-client";

export function LandingHeroCta() {
  const [authed, setAuthed] = useState(false);

  useEffect(() => {
    setAuthed(isAuthenticatedClient());
  }, []);

  return (
    <div className="hero-actions">
      <Link
        className="button button-primary large"
        to={authed ? "/app" : "/login"}
      >
        {authed ? "Open your Hisaab" : "Start your free Hisaab"}
        <ArrowRight size={19} aria-hidden="true" />
      </Link>
      <span>No card required. Your records stay private.</span>
    </div>
  );
}
