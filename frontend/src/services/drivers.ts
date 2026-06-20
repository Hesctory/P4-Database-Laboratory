import { apiGet } from "./api";
import type { DriverDashboardData } from "@/types";

export function getDriverDashboard(): Promise<DriverDashboardData> {
  return apiGet("/api/driver/dashboard");
}
