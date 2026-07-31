import { type ReactNode, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { isAuthenticatedClient } from "@/lib/api-client";

export function AuthRedirect({
  children,
  whenAuthenticated,
  goTo,
}: {
  children: ReactNode;
  whenAuthenticated: boolean;
  goTo: string;
}) {
  const navigate = useNavigate();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const authed = isAuthenticatedClient();
    if (whenAuthenticated && authed) {
      void navigate(goTo, { replace: true });
      return;
    }
    if (!whenAuthenticated && !authed) {
      void navigate(goTo, { replace: true });
      return;
    }
    setReady(true);
  }, [goTo, navigate, whenAuthenticated]);

  if (!ready) {
    return (
      <main className="login-page" style={{ placeItems: "center" }}>
        <p>Loading…</p>
      </main>
    );
  }

  return <>{children}</>;
}
