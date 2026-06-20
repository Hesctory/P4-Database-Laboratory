import { Navigate, Route, Routes, useNavigate } from "react-router-dom";
import { useState } from "react";
import type { User } from "@/types";
import { currentUser, logout } from "@/services/auth";
import { LoginView } from "@/components/views/LoginView";
import { DashboardView } from "@/components/views/DashboardView";
import { ReportsView } from "@/components/views/ReportsView";
import { AppLayout } from "@/components/views/AppLayout";

/**
 * Screen flow required by the statement:
 *   /login  →  /dashboard  →  /reports (and back)
 * Routes other than /login require an authenticated user.
 */
export default function App() {
  const [user, setUser] = useState<User | null>(currentUser());
  const navigate = useNavigate();

  async function handleLogout() {
    await logout();
    setUser(null);
    navigate("/login");
  }

  if (!user) {
    return (
      <Routes>
        <Route path="/login" element={<LoginView onLogin={setUser} />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    );
  }

  return (
    <Routes>
      <Route element={<AppLayout user={user} onLogout={handleLogout} />}>
        <Route path="/dashboard" element={<DashboardView user={user} />} />
        <Route path="/reports" element={<ReportsView user={user} />} />
      </Route>
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}
