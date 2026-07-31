import {
  ArrowRight,
  CheckCircle2,
  CircleAlert,
  KeyRound,
  LoaderCircle,
  Pencil,
  Phone,
  ShieldCheck,
} from "lucide-react";
import { type FormEvent, useEffect, useState } from "react";
import { Brand } from "@/components/Brand";
import { apiFetch, setSessionToken } from "@/lib/api-client";

type OtpRequest = {
  challengeId: string;
  phoneE164: string;
  maskedPhone: string;
  expiresInSeconds: number;
  resendAfterSeconds: number;
  developmentCode?: string;
};

export function LoginPage() {
  const [phone, setPhone] = useState("+91 ");
  const [challenge, setChallenge] = useState<OtpRequest | null>(null);
  const [code, setCode] = useState("");
  const [countdown, setCountdown] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (countdown <= 0) return;
    const timer = window.setInterval(
      () => setCountdown((value) => Math.max(0, value - 1)),
      1_000,
    );
    return () => window.clearInterval(timer);
  }, [countdown]);

  async function requestCode(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault();
    setLoading(true);
    setError("");
    try {
      const response = await apiFetch("/api/auth/request-otp", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ phone }),
      });
      const body = (await response.json()) as OtpRequest & { error?: string };
      if (!response.ok) {
        setError(body.error ?? "We could not send a code.");
        return;
      }
      setChallenge(body);
      setPhone(body.phoneE164);
      setCountdown(body.resendAfterSeconds);
      setCode(body.developmentCode ?? "");
    } catch {
      setError("Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  async function verifyCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!challenge) return;
    setLoading(true);
    setError("");
    try {
      const response = await apiFetch("/api/auth/verify-otp", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          challengeId: challenge.challengeId,
          phone: challenge.phoneE164,
          code,
        }),
      });
      const body = (await response.json()) as {
        error?: string;
        token?: string;
        user?: { phoneE164?: string };
      };
      if (!response.ok) {
        setError(body.error ?? "That code could not be verified.");
        return;
      }
      if (!body.token) {
        setError("Login response was missing a session token.");
        return;
      }
      setSessionToken(body.token, body.user?.phoneE164 ?? challenge.phoneE164);
      window.location.replace("/app");
    } catch {
      setError("Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-intro">
        <Brand />
        <div>
          <span className="eyebrow">Private business ledger</span>
          <h1>Your Hisaab follows your phone number.</h1>
          <p>
            Verify once with an SMS code. Sign in with the same number on a new
            phone to restore all authorised company records.
          </p>
        </div>
        <ul>
          <li>
            <ShieldCheck /> Server-side, revocable sessions
          </li>
          <li>
            <CheckCircle2 /> No password to remember
          </li>
          <li>
            <CheckCircle2 /> Your ledger stays separated by company
          </li>
        </ul>
      </section>

      <section className="login-card" aria-labelledby="login-title">
        <div className="login-icon">
          {challenge ? <KeyRound /> : <Phone />}
        </div>
        <h2 id="login-title">
          {challenge ? "Enter your verification code" : "Verify your phone"}
        </h2>
        <p>
          {challenge
            ? `We sent a one-time code to ${challenge.maskedPhone}.`
            : "Enter a mobile number with country code. Indian numbers may start with +91."}
        </p>

        {challenge ? (
          <form onSubmit={verifyCode} className="login-form">
            <label>
              <span>One-time code</span>
              <input
                autoFocus
                value={code}
                onChange={(event) =>
                  setCode(event.target.value.replace(/\D/g, "").slice(0, 10))
                }
                inputMode="numeric"
                autoComplete="one-time-code"
                placeholder="6-digit code"
                minLength={4}
                maxLength={10}
                required
              />
            </label>
            {challenge.developmentCode ? (
              <div className="local-otp-note">
                Local test code: <strong>{challenge.developmentCode}</strong>
              </div>
            ) : null}
            {error ? <LoginError message={error} /> : null}
            <button
              className="button button-primary large"
              disabled={loading || code.length < 4}
            >
              {loading ? <LoaderCircle className="spin" /> : <ArrowRight />}
              Verify and open Hisaab
            </button>
            <div className="login-secondary-actions">
              <button
                type="button"
                className="quiet-link"
                onClick={() => {
                  setChallenge(null);
                  setCode("");
                  setError("");
                }}
              >
                <Pencil /> Change number
              </button>
              <button
                type="button"
                className="quiet-link"
                disabled={countdown > 0 || loading}
                onClick={() => void requestCode()}
              >
                {countdown > 0 ? `Resend in ${countdown}s` : "Resend code"}
              </button>
            </div>
          </form>
        ) : (
          <form onSubmit={requestCode} className="login-form">
            <label>
              <span>Mobile number</span>
              <input
                autoFocus
                value={phone}
                onChange={(event) => setPhone(event.target.value)}
                inputMode="tel"
                autoComplete="tel"
                placeholder="+91 98765 43210"
                maxLength={20}
                required
              />
            </label>
            {error ? <LoginError message={error} /> : null}
            <button
              className="button button-primary large"
              disabled={loading || phone.trim().length < 8}
            >
              {loading ? <LoaderCircle className="spin" /> : <ArrowRight />}
              Send verification code
            </button>
          </form>
        )}

        <small className="login-privacy">
          By continuing, you confirm that you control this phone number. SMS
          delivery charges may apply.
        </small>
      </section>
    </main>
  );
}

function LoginError({ message }: { message: string }) {
  return (
    <div className="login-error" role="alert">
      <CircleAlert /> {message}
    </div>
  );
}
