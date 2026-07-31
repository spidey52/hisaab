import {
  createRootRoute,
  createRoute,
  createRouter,
  Navigate,
  Outlet,
  redirect,
} from "@tanstack/react-router";
import { AppShell } from "@/components/AppShell";
import { isAuthenticatedClient } from "@/lib/api-client";
import { LandingPage } from "@/pages/LandingPage";
import { LoginPage } from "@/pages/LoginPage";
import { PrivacyPage } from "@/pages/PrivacyPage";
import { TermsPage } from "@/pages/TermsPage";

const rootRoute = createRootRoute({
  component: Outlet,
  notFoundComponent: () => <Navigate to="/" replace />,
});

const landingRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "/",
  component: LandingPage,
});

const loginRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "login",
  validateSearch: (search: Record<string, unknown>): { redirect?: string } =>
    typeof search.redirect === "string" ? { redirect: search.redirect } : {},
  beforeLoad: () => {
    if (isAuthenticatedClient()) {
      throw redirect({ to: "/app", replace: true });
    }
  },
  component: LoginPage,
});

const privacyRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "privacy",
  component: PrivacyPage,
});

const termsRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "terms",
  component: TermsPage,
});

const appRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: "app",
  beforeLoad: ({ location }) => {
    if (!isAuthenticatedClient()) {
      throw redirect({
        to: "/login",
        search: { redirect: location.href },
        replace: true,
      });
    }
  },
  component: AppShell,
});

const appIndexRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "/",
  component: () => null,
});

const partiesRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "parties",
  component: () => null,
});

const partyRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "parties/$partyId",
  component: () => null,
});

const entriesRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "entries",
  component: () => null,
});

const learnRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "learn",
  component: () => null,
});

const settingsRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "settings",
  component: () => null,
});

const legacyMoreRoute = createRoute({
  getParentRoute: () => appRoute,
  path: "more",
  beforeLoad: () => {
    throw redirect({ to: "/app/settings", replace: true });
  },
});

const routeTree = rootRoute.addChildren([
  landingRoute,
  loginRoute,
  privacyRoute,
  termsRoute,
  appRoute.addChildren([
    appIndexRoute,
    partiesRoute,
    partyRoute,
    entriesRoute,
    learnRoute,
    settingsRoute,
    legacyMoreRoute,
  ]),
]);

export const router = createRouter({
  routeTree,
  defaultPreload: "intent",
  scrollRestoration: true,
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
