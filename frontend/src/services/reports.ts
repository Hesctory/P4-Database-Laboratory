import { apiGet } from "./api";
import type {
  AirportNearCity,
  DriverPointsByYear,
  Report3Data,
  StatusCount,
  TeamDriverWins,
} from "@/types";

// Admin
export function report1(): Promise<StatusCount[]> {
  return apiGet("/api/admin/reports/1");
}

export function report2(city: string): Promise<AirportNearCity[]> {
  return apiGet(`/api/admin/reports/2?city=${encodeURIComponent(city)}`);
}

export function report3(): Promise<Report3Data> {
  return apiGet("/api/admin/reports/3");
}

// Team
export function report4(): Promise<TeamDriverWins[]> {
  return apiGet("/api/team/reports/4");
}

export function report5(): Promise<StatusCount[]> {
  return apiGet("/api/team/reports/5");
}

// Driver
export function report6(): Promise<DriverPointsByYear[]> {
  return apiGet("/api/driver/reports/6");
}

export function report7(): Promise<StatusCount[]> {
  return apiGet("/api/driver/reports/7");
}
