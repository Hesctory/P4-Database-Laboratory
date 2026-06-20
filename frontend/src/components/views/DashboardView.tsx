import type { User } from "@/types";
import { AdminDashboard } from "./AdminDashboard";
import { TeamDashboard } from "./TeamDashboard";
import { DriverDashboard } from "./DriverDashboard";

/** Screen 2 — Dashboard. Varies with the authenticated user type. */
export function DashboardView({ user }: { user: User }) {
  switch (user.type) {
    case "Admin":
      return <AdminDashboard user={user} />;
    case "Team":
      return <TeamDashboard user={user} />;
    case "Driver":
      return <DriverDashboard user={user} />;
  }
}
