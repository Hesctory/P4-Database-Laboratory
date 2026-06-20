import { apiPost, setSession, clearSession, getStoredUser } from "./api";
import type { LoginResponse, User } from "@/types";

export async function login(loginName: string, password: string): Promise<User> {
  const res = await apiPost<LoginResponse>("/api/auth/login", {
    login: loginName,
    password,
  });
  setSession(res.token, res.user);
  return res.user;
}

export async function logout(): Promise<void> {
  try {
    await apiPost("/api/auth/logout");
  } finally {
    clearSession();
  }
}

export function currentUser(): User | null {
  return getStoredUser<User>();
}
