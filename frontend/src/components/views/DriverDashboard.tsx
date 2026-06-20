import { useEffect, useState } from "react";
import { CircleUser } from "lucide-react";
import type { DriverDashboardData, User } from "@/types";
import { getDriverDashboard } from "@/services/drivers";
import { formatPoints } from "@/utils/format";
import { Alert } from "@/components/ui/alert";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

export function DriverDashboard(_props: { user: User }) {
  const [data, setData] = useState<DriverDashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getDriverDashboard().then(setData).catch((e) => setError(e.message));
  }, []);

  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Carregando...</p>;

  return (
    <div className="space-y-6">
      {/* Driver's full name + associated team (statement, Screen 2) */}
      <div className="flex items-center gap-2">
        <CircleUser className="text-primary" size={22} />
        <h1 className="text-xl font-semibold">{data.driver_name}</h1>
        {data.team_name && (
          <span className="text-muted-foreground">— Escuderia: {data.team_name}</span>
        )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardContent className="p-5">
            <div className="text-3xl font-bold">
              {data.first_year ?? "—"} – {data.last_year ?? "—"}
            </div>
            <div className="text-sm text-muted-foreground">
              Período com dados registrados (função armazenada)
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <div className="text-3xl font-bold">{data.circuit_stats.length}</div>
            <div className="text-sm text-muted-foreground">Combinações ano × circuito disputadas</div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Desempenho por ano e circuito</CardTitle>
          <CardDescription>
            Pontos, vitórias e corridas disputadas em cada circuito por temporada
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Ano</TableHead>
                <TableHead>Circuito</TableHead>
                <TableHead className="text-right">Pontos</TableHead>
                <TableHead className="text-right">Vitórias</TableHead>
                <TableHead className="text-right">Corridas</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.circuit_stats.map((s) => (
                <TableRow key={`${s.year}-${s.circuit_name}`}>
                  <TableCell>{s.year}</TableCell>
                  <TableCell>{s.circuit_name}</TableCell>
                  <TableCell className="text-right">{formatPoints(s.points)}</TableCell>
                  <TableCell className="text-right">{s.wins}</TableCell>
                  <TableCell className="text-right">{s.races}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
