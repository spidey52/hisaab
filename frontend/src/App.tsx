import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthRedirect } from "@/components/AuthRedirect";
import { AppShell } from "@/components/AppShell";
import { LandingPage } from "@/pages/LandingPage";
import { LoginPage } from "@/pages/LoginPage";
import { PrivacyPage } from "@/pages/PrivacyPage";
import { TermsPage } from "@/pages/TermsPage";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route
          path="/login"
          element={
            <AuthRedirect whenAuthenticated goTo="/app">
              <LoginPage />
            </AuthRedirect>
          }
        />
        <Route
          path="/app"
          element={
            <AuthRedirect whenAuthenticated={false} goTo="/login">
              <AppShell />
            </AuthRedirect>
          }
        />
        <Route path="/privacy" element={<PrivacyPage />} />
        <Route path="/terms" element={<TermsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
