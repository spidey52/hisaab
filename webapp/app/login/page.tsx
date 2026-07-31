import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { getAuthenticatedIdentity } from "@/lib/server-auth";
import { LoginClient } from "./LoginClient";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Verify your phone",
  description: "Sign in to Hisaab with a one-time code sent to your phone.",
};

export default async function LoginPage() {
  const user = await getAuthenticatedIdentity();
  if (user) redirect("/app");
  return <LoginClient />;
}
