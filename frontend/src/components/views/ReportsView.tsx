import { useEffect, useState } from "react";
import { ArrowLeft, FileText } from "lucide-react";
import type {
  AirportNearCity,
  DriverPointsByYear,
  Report3Data,
  StatusCount,
  TeamDriverWins,
  User,
} from "@/types";
import * as reports from "@/services/reports";
import { formatDate, formatKm, formatPoints } from "@/utils/format";
import { Alert } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

interface ReportDef {
  id: string;
  title: string;
  description: string;
}

const REPORTS_BY_TYPE: Record<User["type"], ReportDef[]> = {
  Admin: [
    { id: "r1", title: "Relatório 1 — Resultados por status", description: "Quantidade de resultados para cada status registrado." },
    { id: "r2", title: "Relatório 2 — Aeroportos próximos a uma cidade", description: "Aeroportos brasileiros (médios/grandes) a até 100 km de cada cidade brasileira com o nome pesquisado." },
    { id: "r3", title: "Relatório 3 — Escuderias e corridas (hierárquico)", description: "Escuderias com nº de pilotos + corridas em três níveis: total, por circuito e por corrida." },
  ],
  Team: [
    { id: "r4", title: "Relatório 4 — Vitórias dos pilotos da escuderia", description: "Pilotos da escuderia e número de vezes em que cada um terminou em 1º lugar." },
    { id: "r5", title: "Relatório 5 — Resultados por status (escuderia)", description: "Quantidade de resultados por status, no escopo da sua escuderia." },
  ],
  Driver: [
    { id: "r6", title: "Relatório 6 — Pontos por ano", description: "Total de pontos por ano de participação, com as corridas em que foram obtidos." },
    { id: "r7", title: "Relatório 7 — Resultados por status (piloto)", description: "Quantidade de resultados por status nas corridas que você disputou." },
  ],
};

/** Screen 3 — Reports. Lists the reports available to the logged-in type;
 *  closing a result returns to this list (statement requirement). */
export function ReportsView({ user }: { user: User }) {
  const [active, setActive] = useState<string | null>(null);

  if (active) {
    return (
      <div className="space-y-4">
        <Button variant="outline" onClick={() => setActive(null)}>
          <ArrowLeft size={15} /> Voltar aos relatórios
        </Button>
        <ReportResult id={active} />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <h1 className="text-xl font-semibold">Relatórios disponíveis</h1>
      <div className="grid gap-4 md:grid-cols-2">
        {REPORTS_BY_TYPE[user.type].map((r) => (
          <Card key={r.id}>
            <CardHeader>
              <div className="flex items-center gap-2">
                <FileText className="text-primary" size={17} />
                <CardTitle className="text-base">{r.title}</CardTitle>
              </div>
              <CardDescription>{r.description}</CardDescription>
            </CardHeader>
            <CardContent>
              <Button onClick={() => setActive(r.id)}>Gerar relatório</Button>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

function ReportResult({ id }: { id: string }) {
  switch (id) {
    case "r1":
      return <StatusReport title="Relatório 1 — Resultados por status" fetcher={reports.report1} />;
    case "r2":
      return <Report2 />;
    case "r3":
      return <Report3 />;
    case "r4":
      return <Report4 />;
    case "r5":
      return <StatusReport title="Relatório 5 — Resultados por status (escuderia)" fetcher={reports.report5} />;
    case "r6":
      return <Report6 />;
    case "r7":
      return <StatusReport title="Relatório 7 — Resultados por status (piloto)" fetcher={reports.report7} />;
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Generic status-count report (Reports 1, 5 and 7 share the same shape)
// ---------------------------------------------------------------------------

function StatusReport({ title, fetcher }: { title: string; fetcher: () => Promise<StatusCount[]> }) {
  const { data, error } = useFetch(fetcher);
  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Gerando relatório...</p>;

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{data.length} status distintos</CardDescription>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">Quantidade</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((s) => (
              <TableRow key={s.status}>
                <TableCell>{s.status}</TableCell>
                <TableCell className="text-right">{s.total}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// Report 2 — airports near a Brazilian city (admin)
// ---------------------------------------------------------------------------

function Report2() {
  const [city, setCity] = useState("");
  const [data, setData] = useState<AirportNearCity[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      setData(await reports.report2(city));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao gerar relatório.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Relatório 2 — Aeroportos próximos a uma cidade</CardTitle>
        <CardDescription>
          Aeroportos brasileiros do tipo médio ou grande a até 100 km de cada cidade brasileira com o
          nome informado
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <form onSubmit={handleSubmit} className="flex items-end gap-2">
          <div className="max-w-xs flex-1 space-y-1.5">
            <Label>Nome da cidade</Label>
            <Input value={city} onChange={(e) => setCity(e.target.value)} placeholder="ex.: Campinas" required />
          </div>
          <Button type="submit" disabled={loading}>
            {loading ? "Gerando..." : "Gerar"}
          </Button>
        </form>

        {error && <Alert variant="error">{error}</Alert>}
        {data !== null &&
          (data.length === 0 ? (
            <Alert variant="info">Nenhum aeroporto encontrado para essa cidade.</Alert>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Cidade pesquisada</TableHead>
                  <TableHead>Código IATA</TableHead>
                  <TableHead>Aeroporto</TableHead>
                  <TableHead>Cidade do aeroporto</TableHead>
                  <TableHead className="text-right">Distância</TableHead>
                  <TableHead>Tipo</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.map((a, i) => (
                  <TableRow key={i}>
                    <TableCell>{a.city_name}</TableCell>
                    <TableCell>{a.iata_code ?? "—"}</TableCell>
                    <TableCell>{a.airport_name}</TableCell>
                    <TableCell>{a.airport_city ?? "—"}</TableCell>
                    <TableCell className="text-right">{formatKm(a.distance_km)}</TableCell>
                    <TableCell>
                      {a.airport_type === "large_airport" ? "Grande porte" : "Médio porte"}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ))}
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// Report 3 — hierarchical report (admin)
// ---------------------------------------------------------------------------

function Report3() {
  const { data, error } = useFetch<Report3Data>(reports.report3);
  const [expanded, setExpanded] = useState<Set<number>>(new Set());

  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Gerando relatório...</p>;

  function toggle(circuitId: number) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(circuitId)) next.delete(circuitId);
      else next.add(circuitId);
      return next;
    });
  }

  const racesByCircuit = new Map<number, typeof data.races>();
  for (const race of data.races) {
    const list = racesByCircuit.get(race.circuit_id) ?? [];
    list.push(race);
    racesByCircuit.set(race.circuit_id, list);
  }

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle>Escuderias cadastradas e número de pilotos</CardTitle>
          <CardDescription>{data.teams.length} escuderias</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Escuderia</TableHead>
                <TableHead className="text-right">Nº de pilotos</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.teams.map((t) => (
                <TableRow key={t.team_name}>
                  <TableCell>{t.team_name}</TableCell>
                  <TableCell className="text-right">{t.driver_count}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Relatório hierárquico de corridas</CardTitle>
          <CardDescription>
            Nível 1: total de corridas registradas — <strong>{data.total_races}</strong>. Clique em um
            circuito para ver as corridas (nível 3).
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Circuito</TableHead>
                <TableHead className="text-right">Corridas</TableHead>
                <TableHead className="text-right">Voltas (mín.)</TableHead>
                <TableHead className="text-right">Voltas (média)</TableHead>
                <TableHead className="text-right">Voltas (máx.)</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.circuits.map((c) => (
                <>
                  <TableRow
                    key={c.circuit_id}
                    className="cursor-pointer"
                    onClick={() => toggle(c.circuit_id)}
                  >
                    <TableCell className="font-medium">
                      {expanded.has(c.circuit_id) ? "▾" : "▸"} {c.circuit_name}
                    </TableCell>
                    <TableCell className="text-right">{c.race_count}</TableCell>
                    <TableCell className="text-right">{c.min_laps ?? "—"}</TableCell>
                    <TableCell className="text-right">{c.avg_laps ?? "—"}</TableCell>
                    <TableCell className="text-right">{c.max_laps ?? "—"}</TableCell>
                  </TableRow>
                  {expanded.has(c.circuit_id) &&
                    (racesByCircuit.get(c.circuit_id) ?? []).map((race) => (
                      <TableRow key={`${c.circuit_id}-${race.year}-${race.race_name}`} className="bg-muted/30">
                        <TableCell className="pl-8 text-muted-foreground">
                          {race.year} — {race.race_name}
                        </TableCell>
                        <TableCell />
                        <TableCell colSpan={2} className="text-right text-muted-foreground">
                          Voltas: {race.laps ?? "—"}
                        </TableCell>
                        <TableCell className="text-right text-muted-foreground">
                          Pilotos: {race.driver_count}
                        </TableCell>
                      </TableRow>
                    ))}
                </>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Report 4 — team driver wins
// ---------------------------------------------------------------------------

function Report4() {
  const { data, error } = useFetch<TeamDriverWins[]>(reports.report4);
  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Gerando relatório...</p>;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Relatório 4 — Vitórias dos pilotos da escuderia</CardTitle>
        <CardDescription>
          Número de vezes que cada piloto terminou em 1º lugar correndo pela escuderia
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Piloto</TableHead>
              <TableHead className="text-right">Vitórias</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.map((d) => (
              <TableRow key={d.full_name}>
                <TableCell>{d.full_name}</TableCell>
                <TableCell className="text-right">{d.wins}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}

// ---------------------------------------------------------------------------
// Report 6 — driver points per year, grouped by year with the year total
// ---------------------------------------------------------------------------

function Report6() {
  const { data, error } = useFetch<DriverPointsByYear[]>(reports.report6);
  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Gerando relatório...</p>;

  const years = [...new Set(data.map((r) => r.year))];

  return (
    <div className="space-y-4">
      {years.map((year) => {
        const rows = data.filter((r) => r.year === year);
        return (
          <Card key={year}>
            <CardHeader>
              <CardTitle>
                {year} — total de {formatPoints(rows[0].year_total)} pontos
              </CardTitle>
              <CardDescription>Corridas em que os pontos foram obtidos</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Corrida</TableHead>
                    <TableHead>Data</TableHead>
                    <TableHead className="text-right">Pontos</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((r) => (
                    <TableRow key={`${r.race_name}-${r.race_date}`}>
                      <TableCell>{r.race_name}</TableCell>
                      <TableCell>{formatDate(r.race_date)}</TableCell>
                      <TableCell className="text-right">{formatPoints(r.points)}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </CardContent>
          </Card>
        );
      })}
      {years.length === 0 && <Alert variant="info">Nenhum ponto registrado para este piloto.</Alert>}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Tiny fetch-on-mount hook shared by the static reports
// ---------------------------------------------------------------------------

function useFetch<T>(fetcher: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    fetcher()
      .then(setData)
      .catch((e: Error) => setError(e.message));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return { data, error };
}
