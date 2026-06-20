// All shapes exchanged with the backend live here (no inline types in components).

export type UserType = "Admin" | "Team" | "Driver";

export interface User {
  userid: number;
  login: string;
  type: UserType;
  original_id: number | null;
  display_name: string;
}

export interface LoginResponse {
  token: string;
  user: User;
}

// ---------- Admin dashboard ----------

export interface AdminTotals {
  total_drivers: number;
  total_teams: number;
  total_seasons: number;
}

export interface SeasonRace {
  round: number;
  race_name: string;
  circuit_name: string;
  race_date: string | null;
  race_time: string | null;
  laps: number | null;
}

export interface SeasonTeamPoints {
  team_name: string;
  total_points: number;
}

export interface SeasonDriverPoints {
  driver_name: string;
  total_points: number;
}

export interface AdminDashboardData {
  totals: AdminTotals;
  latest_season: number | null;
  races: SeasonRace[];
  teams: SeasonTeamPoints[];
  drivers: SeasonDriverPoints[];
}

// ---------- Team dashboard / actions ----------

export interface TeamDashboardData {
  team_name: string;
  wins: number;
  driver_count: number;
  first_year: number | null;
  last_year: number | null;
}

export interface DriverSearchResult {
  full_name: string;
  date_of_birth: string | null;
  country: string | null;
}

export interface UploadResult {
  inserted: string[];
  errors: string[];
}

// ---------- Driver dashboard ----------

export interface DriverCircuitStat {
  year: number;
  circuit_name: string;
  points: number;
  wins: number;
  races: number;
}

export interface DriverDashboardData {
  driver_name: string;
  team_name: string | null;
  first_year: number | null;
  last_year: number | null;
  circuit_stats: DriverCircuitStat[];
}

// ---------- Reports ----------

export interface StatusCount {
  status: string;
  total: number;
}

export interface AirportNearCity {
  city_name: string;
  iata_code: string | null;
  airport_name: string;
  airport_city: string | null;
  distance_km: number;
  airport_type: string;
}

export interface TeamDriverWins {
  full_name: string;
  wins: number;
}

export interface TeamWithDriverCount {
  team_name: string;
  driver_count: number;
}

export interface CircuitRaceStats {
  circuit_id: number;
  circuit_name: string;
  race_count: number;
  min_laps: number | null;
  avg_laps: number | null;
  max_laps: number | null;
}

export interface RacePerCircuit {
  circuit_id: number;
  race_name: string;
  year: number;
  laps: number | null;
  driver_count: number;
}

export interface Report3Data {
  teams: TeamWithDriverCount[];
  total_races: number;
  circuits: CircuitRaceStats[];
  races: RacePerCircuit[];
}

export interface DriverPointsByYear {
  year: number;
  race_name: string;
  race_date: string | null;
  points: number;
  year_total: number;
}

// ---------- Misc ----------

export interface Country {
  id: number;
  name: string;
}

export interface NewTeam {
  constructor_ref: string;
  name: string;
  country_id: number;
  wikipedia_url: string | null;
}

export interface NewDriver {
  driver_ref: string;
  given_name: string;
  family_name: string;
  date_of_birth: string | null;
  country_id: number;
}
