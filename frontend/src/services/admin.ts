import { apiGet, apiPost } from "./api";
import type { AdminDashboardData, Country, NewDriver, NewTeam } from "@/types";

export function getAdminDashboard(): Promise<AdminDashboardData> {
  return apiGet("/api/admin/dashboard");
}

export function getCountries(): Promise<Country[]> {
  return apiGet("/api/admin/countries");
}

export function registerTeam(team: NewTeam): Promise<{ ok: boolean }> {
  return apiPost("/api/admin/teams", team);
}

export function registerDriver(driver: NewDriver): Promise<{ ok: boolean }> {
  return apiPost("/api/admin/drivers", driver);
}
