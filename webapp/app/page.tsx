import {
  ArrowRight,
  CheckCircle2,
  Cloud,
  FileText,
  ShieldCheck,
  Smartphone,
} from "lucide-react";
import { Brand } from "./components/Brand";
import { getAuthenticatedIdentity } from "@/lib/server-auth";

export const dynamic = "force-dynamic";

export default async function Home() {
  const user = await getAuthenticatedIdentity();
  return (
    <main className="landing">
      <header className="landing-header">
        <Brand />
        <nav className="landing-nav" aria-label="Main navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#safety">Safety</a>
          {user ? (
            <>
              <a className="button button-secondary compact" href="/app">
                Open Hisaab
              </a>
              <form action="/api/auth/logout" method="post">
                <button className="quiet-link">Sign out</button>
              </form>
            </>
          ) : (
            <a
              className="button button-primary compact"
              href="/login"
            >
              Sign in
            </a>
          )}
        </nav>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <h1>Know exactly who owes what.</h1>
          <p>
            A simple, secure ledger for Indian shops and small businesses.
            Record sales, payments and opening balances without accounting
            jargon.
          </p>
          <div className="hero-actions">
            <a
              className="button button-primary large"
              href={user ? "/app" : "/login"}
            >
              {user ? "Open your Hisaab" : "Start your free Hisaab"}
              <ArrowRight size={19} aria-hidden="true" />
            </a>
            <span>No card required. Your records stay private.</span>
          </div>
        </div>
        <div className="hero-ledger" aria-label="Example Hisaab ledger">
          <div className="hero-ledger-head">
            <div>
              <span>You will receive</span>
              <strong>₹12,450</strong>
            </div>
            <ShieldCheck size={28} aria-hidden="true" />
          </div>
          <div className="hero-party-row">
            <span className="avatar">RK</span>
            <div>
              <strong>Ramesh Kirana</strong>
              <small>Goods · Today</small>
            </div>
            <div className="amount receive">
              <strong>₹2,600</strong>
              <small>You will receive</small>
            </div>
          </div>
          <div className="hero-party-row">
            <span className="avatar amber">MS</span>
            <div>
              <strong>Meena Stores</strong>
              <small>Payment · Yesterday</small>
            </div>
            <div className="amount pay">
              <strong>₹850</strong>
              <small>You will pay</small>
            </div>
          </div>
          <div className="preview-copy">
            <CheckCircle2 size={20} aria-hidden="true" />
            After this entry, you will receive ₹600 from Ramesh Kirana.
          </div>
        </div>
      </section>

      <section className="promise-strip" id="how-it-works">
        <div>
          <Smartphone aria-hidden="true" />
          <strong>Phone OTP sign-in</strong>
          <span>No password—verify your mobile number with a one-time code.</span>
        </div>
        <div>
          <Cloud aria-hidden="true" />
          <strong>Safe online and offline</strong>
          <span>Queue entries offline and upload them automatically.</span>
        </div>
        <div>
          <FileText aria-hidden="true" />
          <strong>History you can trust</strong>
          <span>Edits and cancellations stay visible and auditable.</span>
        </div>
      </section>

      <section className="safety-section" id="safety">
        <div>
          <h2>Built for everyday business, not accountants.</h2>
          <p>
            Add a person with just their name. Tap You gave or You got, then
            enter the amount. Notes and older dates are optional, and Hisaab
            shows the new balance in plain language before you save.
          </p>
        </div>
        <ul>
          <li>
            <CheckCircle2 aria-hidden="true" /> Automatic entry numbers
          </li>
          <li>
            <CheckCircle2 aria-hidden="true" /> Secure company separation
          </li>
          <li>
            <CheckCircle2 aria-hidden="true" /> Shareable statements
          </li>
          <li>
            <CheckCircle2 aria-hidden="true" /> Export and account deletion
          </li>
        </ul>
      </section>

      <footer className="landing-footer">
        <Brand />
        <p>
          Hisaab tracks recorded customer and supplier activity. Recorded Cash
          and Bank movement may not match actual account balances.
        </p>
        <nav aria-label="Legal">
          <a href="/privacy">Privacy</a>
          <a href="/terms">Terms</a>
        </nav>
      </footer>
    </main>
  );
}
