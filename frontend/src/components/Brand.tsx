import { Link } from "react-router-dom";

export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <Link className={`brand ${compact ? "brand-compact" : ""}`} to="/">
      <span className="brand-mark" aria-hidden="true">
        ₹
      </span>
      <span>Hisaab</span>
    </Link>
  );
}
