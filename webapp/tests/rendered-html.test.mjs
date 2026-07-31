import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { after, before, test } from "node:test";

const port = 4175;
const origin = `http://127.0.0.1:${port}`;
let server;

before(async () => {
  const nextBin = fileURLToPath(
    new URL("../node_modules/next/dist/bin/next", import.meta.url),
  );
  server = spawn(
    process.execPath,
    [nextBin, "start", "--hostname", "127.0.0.1", "--port", String(port)],
    {
      cwd: new URL("../", import.meta.url),
      env: {
        ...process.env,
        NODE_ENV: "production",
        PUBLIC_BASE_URL: origin,
        SESSION_SECRET: "test-only-session-secret-with-at-least-32-characters",
        SUPPORT_EMAIL: "support@example.com",
      },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );

  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) {
      throw new Error("The production server exited before tests started.");
    }
    try {
      const response = await fetch(origin, { redirect: "manual" });
      if (response.status > 0) return;
    } catch {
      // Keep polling while the production server starts.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("Timed out waiting for the production server.");
});

after(() => {
  server?.kill("SIGTERM");
});

test("server-renders the public Hisaab landing page", async () => {
  const response = await fetch(origin);
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Hisaab — Simple business ledger<\/title>/i);
  assert.match(html, /Know exactly who owes what\./);
  assert.match(html, /Start your free Hisaab/);
  assert.match(html, /href="\/login"/);
  assert.match(html, /Phone OTP sign-in/);
  assert.match(html, /\/og\.jpg/);
  assert.match(html, /\/manifest\.webmanifest/);
  assert.doesNotMatch(
    html,
    /demo@hisaab\.local|Starter Project|codex-preview|ChatGPT|Cloudflare/i,
  );
});

test("protects the app and API while keeping phone login public", async () => {
  const [
    appResponse,
    loginResponse,
    apiResponse,
    crossSiteResponse,
    wrongContentTypeResponse,
    oversizedResponse,
    privacyResponse,
    termsResponse,
    formLogoutResponse,
  ] =
    await Promise.all([
      fetch(`${origin}/app`, { redirect: "manual" }),
      fetch(`${origin}/login`, { redirect: "manual" }),
      fetch(`${origin}/api/bootstrap`, { redirect: "manual" }),
      fetch(`${origin}/api/auth/logout`, {
        method: "POST",
        headers: {
          origin: "https://attacker.example",
          "sec-fetch-site": "cross-site",
        },
      }),
      fetch(`${origin}/api/auth/request-otp`, {
        method: "POST",
        headers: { "content-type": "text/plain" },
        body: "{}",
      }),
      fetch(`${origin}/api/auth/request-otp`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ phone: "1".repeat(3_000) }),
      }),
      fetch(`${origin}/privacy`),
      fetch(`${origin}/terms`),
      fetch(`${origin}/api/auth/logout`, {
        method: "POST",
        redirect: "manual",
        headers: {
          accept: "text/html",
          origin,
        },
      }),
    ]);

  assert.equal(appResponse.status, 307);
  assert.equal(appResponse.headers.get("location"), "/login");
  assert.equal(loginResponse.status, 200);
  assert.match(await loginResponse.text(), /Verify your phone/);
  assert.equal(apiResponse.status, 401);
  assert.equal(crossSiteResponse.status, 403);
  assert.equal(wrongContentTypeResponse.status, 415);
  assert.equal(oversizedResponse.status, 413);
  assert.equal(privacyResponse.status, 200);
  assert.match(await privacyResponse.text(), /support@example\.com/);
  assert.equal(termsResponse.status, 200);
  assert.equal(formLogoutResponse.status, 303);
  assert.equal(formLogoutResponse.headers.get("location"), "/");
});

test("uses PostgreSQL, server-side phone sessions, and no hosted Sites runtime", async () => {
  const [serverAuth, phoneAuth, loginClient, productionCompose, apiSources] =
    await Promise.all([
      readFile(new URL("../lib/server-auth.ts", import.meta.url), "utf8"),
      readFile(new URL("../lib/phone-auth.ts", import.meta.url), "utf8"),
      readFile(new URL("../app/login/LoginClient.tsx", import.meta.url), "utf8"),
      readFile(new URL("../compose.production.yml", import.meta.url), "utf8"),
      Promise.all([
        ...[
          "account",
          "bootstrap",
          "entries",
          "export",
          "groups",
          "opening-balance",
          "parties",
          "settings",
        ].map((route) =>
          readFile(
            new URL(`../app/api/${route}/route.ts`, import.meta.url),
            "utf8",
          ),
        ),
        readFile(
          new URL(
            "../app/api/parties/[id]/statement/route.ts",
            import.meta.url,
          ),
          "utf8",
        ),
      ]),
    ]);

  assert.match(serverAuth, /getPhoneSessionIdentity/);
  assert.match(phoneAuth, /TWILIO_VERIFY_SERVICE_SID/);
  assert.match(phoneAuth, /httpOnly: true/);
  assert.match(phoneAuth, /timingSafeEqual/);
  assert.match(loginClient, /setCode\(body\.developmentCode \?\? ""\)/);
  assert.match(productionCompose, /postgres:17-alpine/);
  assert.match(productionCompose, /caddy:2\.10-alpine/);
  assert.doesNotMatch(
    `${serverAuth}\n${phoneAuth}\n${productionCompose}`,
    /ChatGPT|Cloudflare|\.openai\/hosting/i,
  );
  for (const source of apiSources) {
    assert.match(source, /require(?:Server|Mutation)Context\(/);
  }
});
