import type { Metadata, Viewport } from "next";
import { headers } from "next/headers";
import "./globals.css";

const description =
  "Track what customers and suppliers owe you, safely and simply.";

export const viewport: Viewport = {
  themeColor: "#08783e",
  colorScheme: "light",
};

export async function generateMetadata(): Promise<Metadata> {
  const requestHeaders = await headers();
  const host =
    requestHeaders.get("x-forwarded-host") ??
    requestHeaders.get("host") ??
    "localhost:3000";
  const protocol =
    requestHeaders.get("x-forwarded-proto") ??
    (host.startsWith("localhost") ? "http" : "https");
  const origin = `${protocol}://${host}`;
  const socialImage = `${origin}/og.jpg`;

  return {
    title: {
      default: "Hisaab — Simple business ledger",
      template: "%s · Hisaab",
    },
    description,
    applicationName: "Hisaab",
    icons: {
      icon: "/favicon.png",
      shortcut: "/favicon.png",
      apple: "/favicon.png",
    },
    manifest: "/manifest.webmanifest",
    openGraph: {
      type: "website",
      url: origin,
      siteName: "Hisaab",
      title: "Hisaab — Know exactly who owes what.",
      description,
      images: [
        {
          url: socialImage,
          width: 1200,
          height: 675,
          alt: "Hisaab — Know exactly who owes what.",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: "Hisaab — Know exactly who owes what.",
      description,
      images: [socialImage],
    },
  };
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
