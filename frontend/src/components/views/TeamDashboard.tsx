import { useEffect, useState } from "react";
import { FileUp, Search, Trophy, Users } from "lucide-react";
import type { DriverSearchResult, TeamDashboardData, UploadResult, User } from "@/types";
import { getTeamDashboard, searchDriverBySurname, uploadDriversFile } from "@/services/teams";
import { formatDate } from "@/utils/format";
import { Alert } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

export function TeamDashboard(_props: { user: User }) {
  const [data, setData] = useState<TeamDashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [openDialog, setOpenDialog] = useState<"search" | "upload" | null>(null);

  useEffect(() => {
    getTeamDashboard().then(setData).catch((e) => setError(e.message));
  }, []);

  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Carregando...</p>;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Users className="text-primary" size={22} />
          <h1 className="text-xl font-semibold">Escuderia {data.team_name}</h1>
        </div>
        <div className="flex gap-2">
          <Button onClick={() => setOpenDialog("search")}>
            <Search size={15} /> Buscar piloto por sobrenome
          </Button>
          <Button onClick={() => setOpenDialog("upload")}>
            <FileUp size={15} /> Inserir pilotos por arquivo
          </Button>
        </div>
      </div>

      {/* Stored functions fn_team_* feed these cards */}
      <div className="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardContent className="p-5">
            <div className="flex items-center gap-2">
              <Trophy className="text-primary" size={18} />
              <div className="text-3xl font-bold">{data.wins}</div>
            </div>
            <div className="text-sm text-muted-foreground">Vitórias (1º lugar)</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <div className="text-3xl font-bold">{data.driver_count}</div>
            <div className="text-sm text-muted-foreground">Pilotos que já correram pela escuderia</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-5">
            <div className="text-3xl font-bold">
              {data.first_year ?? "—"} – {data.last_year ?? "—"}
            </div>
            <div className="text-sm text-muted-foreground">Período com dados registrados</div>
          </CardContent>
        </Card>
      </div>

      <SearchDriverDialog open={openDialog === "search"} onClose={() => setOpenDialog(null)} />
      <UploadDriversDialog open={openDialog === "upload"} onClose={() => setOpenDialog(null)} />
    </div>
  );
}

/** Action: query a driver by last name among those who raced for the team. */
function SearchDriverDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [surname, setSurname] = useState("");
  const [results, setResults] = useState<DriverSearchResult[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      setResults(await searchDriverBySurname(surname));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro na busca.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={onClose} title="Buscar piloto por sobrenome" className="max-w-2xl">
      <form onSubmit={handleSubmit} className="flex items-end gap-2">
        <div className="flex-1 space-y-1.5">
          <Label>Sobrenome do piloto</Label>
          <Input
            value={surname}
            onChange={(e) => setSurname(e.target.value)}
            placeholder="ex.: Senna"
            required
          />
        </div>
        <Button type="submit" disabled={loading}>
          {loading ? "Buscando..." : "Buscar"}
        </Button>
      </form>

      {error && <Alert variant="error" className="mt-3">{error}</Alert>}

      {results !== null && (
        <div className="mt-4">
          {results.length === 0 ? (
            <Alert variant="info">
              Nenhum piloto com esse sobrenome correu pela sua escuderia.
            </Alert>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Nome completo</TableHead>
                  <TableHead>Data de nascimento</TableHead>
                  <TableHead>País / Nacionalidade</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {results.map((d) => (
                  <TableRow key={d.full_name}>
                    <TableCell>{d.full_name}</TableCell>
                    <TableCell>{formatDate(d.date_of_birth)}</TableCell>
                    <TableCell>{d.country ?? "—"}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </div>
      )}
    </Dialog>
  );
}

/** Action: insert new drivers from a file (one driver per line). */
function UploadDriversDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<UploadResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!file) return;
    setError(null);
    setResult(null);
    setLoading(true);
    try {
      setResult(await uploadDriversFile(file));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro no envio do arquivo.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <Dialog open={open} onClose={onClose} title="Inserir pilotos por arquivo" className="max-w-2xl">
      <Card className="mb-3 border-dashed">
        <CardHeader>
          <CardTitle className="text-sm">Formato esperado do arquivo (.txt / .csv)</CardTitle>
          <CardDescription>
            Uma linha por piloto:{" "}
            <code className="rounded bg-muted px-1">
              driver_ref,nome,sobrenome,data_nascimento,id_pais
            </code>
            <br />
            Exemplo: <code className="rounded bg-muted px-1">piloto_novo,João,Silva,2000-05-10,30</code>
          </CardDescription>
        </CardHeader>
      </Card>

      <form onSubmit={handleSubmit} className="flex items-end gap-2">
        <div className="flex-1 space-y-1.5">
          <Label>Arquivo</Label>
          <Input
            type="file"
            accept=".txt,.csv"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
            required
          />
        </div>
        <Button type="submit" disabled={loading || !file}>
          {loading ? "Enviando..." : "Inserir pilotos"}
        </Button>
      </form>

      {error && <Alert variant="error" className="mt-3">{error}</Alert>}

      {result && (
        <div className="mt-4 space-y-2">
          {result.inserted.length > 0 && (
            <Alert variant="success">
              <strong>{result.inserted.length} piloto(s) inserido(s):</strong>
              <ul className="ml-4 list-disc">
                {result.inserted.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
            </Alert>
          )}
          {result.errors.length > 0 && (
            <Alert variant="error">
              <strong>{result.errors.length} linha(s) com problema:</strong>
              <ul className="ml-4 list-disc">
                {result.errors.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ul>
            </Alert>
          )}
          {result.inserted.length === 0 && result.errors.length === 0 && (
            <Alert variant="info">O arquivo não continha linhas válidas.</Alert>
          )}
        </div>
      )}
    </Dialog>
  );
}
