import { Link, Outlet, useLocation } from "react-router-dom";
import { Flag, LogOut } from "lucide-react";
import type { User } from "@/types";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

const TYPE_LABEL: Record<User["type"], string> = {
  Admin: "Administrador",
  Team: "Escuderia",
  Driver: "Piloto",
};

/** Shared header: logged-in user identification + navigation + logout. */
export function AppLayout({ user, onLogout }: { user: User; onLogout: () => void }) {
  const { pathname } = useLocation();

  const navLink = (to: string, label: string) => (
    <Link
      to={to}
      className={cn(
        "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
        pathname === to ? "bg-primary text-primary-foreground" : "hover:bg-muted"
      )}
    >
      {label}
    </Link>
  );

  return (
    <div className="min-h-screen">
      <header className="border-b border-border bg-card">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
          <div className="flex items-center gap-2">
            <Flag className="text-primary" size={20} />
            <span className="font-semibold">F1 FIA Database</span>
          </div>
          <nav className="flex items-center gap-1">
            {navLink("/dashboard", "Dashboard")}
            {navLink("/reports", "Relatórios")}
          </nav>
          <div className="flex items-center gap-3">
            <div className="text-right text-sm">
              <div className="font-medium">{user.display_name}</div>
              <Badge variant="secondary">{TYPE_LABEL[user.type]}</Badge>
            </div>
            <Button variant="outline" size="sm" onClick={onLogout}>
              <LogOut size={14} /> Sair
            </Button>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
