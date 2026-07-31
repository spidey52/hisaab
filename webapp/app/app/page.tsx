import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getAuthenticatedIdentity } from "@/lib/server-auth";
import { HisaabClient } from "./HisaabClient";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Your ledger",
  description: "Your secure Hisaab customer and supplier ledger.",
};

export default async function AppPage() {
  const user = await getAuthenticatedIdentity();
  if (!user) redirect("/login");
  return <HisaabClient signedInPhone={user.phoneE164} />;
}
