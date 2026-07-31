import { Link } from "react-router-dom";
import { Brand } from "@/components/Brand";

export function PrivacyPage() {
  const supportEmail = import.meta.env.VITE_SUPPORT_EMAIL?.trim() ||
    "support@localhost";

  return (
    <main className="legal-page">
      <header>
        <Brand />
        <Link to="/">Back to Hisaab</Link>
      </header>
      <article>
        <span className="eyebrow">Effective 30 July 2026</span>
        <h1>Privacy notice</h1>
        <p>
          Hisaab stores the information needed to provide your private business
          ledger. The operator of this deployment controls that data and the
          server where it is hosted.
        </p>

        <h2>Information we process</h2>
        <p>
          We store your verified phone number, optional profile name, company
          settings, customers and suppliers, ledger entries, revision history,
          and security records. Authentication logs use one-way hashes for phone
          and IP values. Session tokens are random identifiers sent as Bearer
          tokens; only their hashes are stored in PostgreSQL.
        </p>

        <h2>Why and how it is used</h2>
        <p>
          This information is used only to authenticate you, provide ledger
          functions, prevent abuse, preserve audit history, and operate the
          service. Hisaab does not include advertising trackers or sell personal
          information.
        </p>

        <h2>Phone verification</h2>
        <p>
          This deployment generates and validates one-time codes on its own
          server. It does not send your phone number to an external SMS
          verification provider.
        </p>

        <h2>Optional contact discovery</h2>
        <p>
          If you choose to find Hisaab users from your contacts, your device
          sends a limited batch of normalized phone numbers to this Hisaab
          deployment. The server returns only which submitted numbers belong to
          users who have opted in to being discoverable. It does not return
          names, companies, or ledger data, and it does not store the submitted
          contact list. Aggregate request and batch-size counts—not the
          submitted numbers—are retained to prevent abuse. You can keep using
          Hisaab and add a party manually without granting contacts permission.
        </p>

        <h2>Retention and control</h2>
        <p>
          Expired OTP challenges are removed after one day, old authentication
          events after 90 days, and expired or revoked sessions after their
          retention window. Ledger data remains until the account owner exports
          or permanently deletes the account. Server backups may retain deleted
          data until the operator&apos;s backup rotation completes.
        </p>

        <h2>Security and contact</h2>
        <p>
          Hisaab uses encrypted transport in production, company-scoped access,
          revocable sessions, request limits, and database constraints. No
          system can guarantee absolute security. For access, correction,
          deletion, or privacy questions, email{" "}
          <a href={`mailto:${supportEmail}`}>{supportEmail}</a>.
        </p>
      </article>
    </main>
  );
}
