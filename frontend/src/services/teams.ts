import { apiGet, apiPostFile } from "./api";
import type { DriverSearchResult, TeamDashboardData, UploadResult } from "@/types";

export function getTeamDashboard(): Promise<TeamDashboardData> {
  return apiGet("/api/team/dashboard");
}

export function searchDriverBySurname(familyName: string): Promise<DriverSearchResult[]> {
  return apiGet(`/api/team/drivers/by-surname?family_name=${encodeURIComponent(familyName)}`);
}

export function uploadDriversFile(file: File): Promise<UploadResult> {
  return apiPostFile("/api/team/drivers/upload", file);
}
