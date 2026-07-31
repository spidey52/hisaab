import { Link } from "@tanstack/react-router";
import { Brand } from "@/components/Brand";

export function TermsPage() {
  const supportEmail = import.meta.env.VITE_SUPPORT_EMAIL?.trim() ||
    "support@localhost";

  return (
    <main className="legal-page">
      <header>
        <Brand />
        <Link to="/">Back to Hisaab</Link>
      </header>
      <article>
        <span className="eyebrow">Effective 29 July 2026</span>
        <h1>Terms of use</h1>
        <p>
          By using this Hisaab deployment, you agree to these terms with the
          operator of the service.
        </p>

        <h2>Your account</h2>
        <p>
          You must control the phone number used to sign in and keep your device
          and active sessions secure. You are responsible for activity performed
          through your account and for keeping recovery information current.
        </p>

        <h2>Your records</h2>
        <p>
          You retain responsibility for the data you enter and must have the
          right to store customer, supplier, and transaction information. Do not
          use Hisaab for unlawful, fraudulent, abusive, or privacy-infringing
          activity.
        </p>

        <h2>Financial accuracy</h2>
        <p>
          Hisaab is a record-keeping aid, not accounting, tax, legal, lending,
          or banking advice. Review entries and exports before relying on them.
          Recorded Cash and Bank labels describe customer-linked movements and
          may not equal real-world account balances.
        </p>

        <h2>Availability and backups</h2>
        <p>
          The service may be interrupted for maintenance or circumstances beyond
          the operator&apos;s control. Use the export feature and keep
          independent backups appropriate to your business.
        </p>

        <h2>Account closure and contact</h2>
        <p>
          The owner can permanently delete an account from Hisaab. The operator
          may restrict abusive or unlawful use. Questions about these terms can
          be sent to <a href={`mailto:${supportEmail}`}>{supportEmail}</a>.
        </p>
      </article>
    </main>
  );
}
