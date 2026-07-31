import { getSessionPhone } from "@/lib/api-client";
import { HisaabClient } from "@/pages/HisaabApp";

export function AppShell() {
  const phone = getSessionPhone() ?? "session";
  return <HisaabClient signedInPhone={phone} />;
}
