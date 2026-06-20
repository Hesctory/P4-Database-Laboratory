import { useEffect, useState } from "react";
import { ShieldCheck, UserPlus, Users } from "lucide-react";
import type { AdminDashboardData, Country, User } from "@/types";
import { getAdminDashboard, getCountries, registerDriver, registerTeam } from "@/services/admin";
import { formatDate, formatPoints, formatTime } from "@/utils/format";
import { Alert } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";

export function AdminDashboard({ user }: { user: User }) {
  const [data, setData] = useState<AdminDashboardData | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [openDialog, setOpenDialog] = useState<"team" | "driver" | null>(null);

  function load() {
    getAdminDashboard().then(setData).catch((e) => setError(e.message));
  }
  useEffect(load, []);

  if (error) return <Alert variant="error">{error}</Alert>;
  if (!data) return <p className="text-muted-foreground">Carregando...</p>;

  return (
    <div className="space-y-6">
      {/* Identification of the logged-in user as administrator */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <ShieldCheck className="text-primary" size={22} />
          <h1 className="text-xl font-semibold">
            {user.display_name} — acesso de Administrador
          </h1>
        </div>
        <div className="flex gap-2">
          <Button onClick={() => setOpenDialog("team")}>
            <Users size={15} /> Cadastrar Escuderia
          </Button>
          <Button onClick={() => setOpenDialog("driver")}>
            <UserPlus size={15} /> Cadastrar Piloto
          </Button>
        </div>
      </div>

      {/* 1. Totals */}
      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label="Pilotos cadastrados" value={data.totals.total_drivers} />
        <StatCard label="Escuderias cadastradas" value={data.totals.total_teams} />
        <StatCard label="Temporadas cadastradas" value={data.totals.total_seasons} />
      </div>

      {/* 2. Races of the most recent season */}
      <Card>
        <CardHeader>
          <CardTitle>Corridas da temporada {data.latest_season}</CardTitle>
          <CardDescription>Circuito, data, horário e voltas registradas nos resultados</CardDescription>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Etapa</TableHead>
                <TableHead>Corrida</TableHead>
                <TableHead>Circuito</TableHead>
                <TableHead>Data</TableHead>
                <TableHead>Horário</TableHead>
                <TableHead className="text-right">Voltas</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {data.races.map((r) => (
                <TableRow key={r.round}>
                  <TableCell>{r.round}</TableCell>
                  <TableCell>{r.race_name}</TableCell>
                  <TableCell>{r.circuit_name}</TableCell>
                  <TableCell>{formatDate(r.race_date)}</TableCell>
                  <TableCell>{formatTime(r.race_time)}</TableCell>
                  <TableCell className="text-right">{r.laps ?? "—"}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* 3 & 4. Teams and drivers of the most recent season with points */}
      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Escuderias da temporada {data.latest_season}</CardTitle>
            <CardDescription>Total de pontos obtidos</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Escuderia</TableHead>
                  <TableHead className="text-right">Pontos</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.teams.map((t) => (
                  <TableRow key={t.team_name}>
                    <TableCell>{t.team_name}</TableCell>
                    <TableCell className="text-right">{formatPoints(t.total_points)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Pilotos da temporada {data.latest_season}</CardTitle>
            <CardDescription>Total de pontos obtidos</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Piloto</TableHead>
                  <TableHead className="text-right">Pontos</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {data.drivers.map((d) => (
                  <TableRow key={d.driver_name}>
                    <TableCell>{d.driver_name}</TableCell>
                    <TableCell className="text-right">{formatPoints(d.total_points)}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>

      <RegisterTeamDialog
        open={openDialog === "team"}
        onClose={() => setOpenDialog(null)}
        onSaved={load}
      />
      <RegisterDriverDialog
        open={openDialog === "driver"}
        onClose={() => setOpenDialog(null)}
        onSaved={load}
      />
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <Card>
      <CardContent className="p-5">
        <div className="text-3xl font-bold">{value}</div>
        <div className="text-sm text-muted-foreground">{label}</div>
      </CardContent>
    </Card>
  );
}

/** Shared country <select> loaded from the backend. */
function CountrySelect({
  countries,
  value,
  onChange,
}: {
  countries: Country[];
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <select
      className="flex h-9 w-full rounded-md border border-input bg-card px-3 py-1 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      required
    >
      <option value="">Selecione o país...</option>
      {countries.map((c) => (
        <option key={c.id} value={c.id}>
          {c.name}
        </option>
      ))}
    </select>
  );
}

function useCountries(open: boolean): Country[] {
  const [countries, setCountries] = useState<Country[]>([]);
  useEffect(() => {
    if (open && countries.length === 0) {
      getCountries().then(setCountries).catch(() => setCountries([]));
    }
  }, [open, countries.length]);
  return countries;
}

function RegisterTeamDialog({
  open,
  onClose,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const countries = useCountries(open);
  const [form, setForm] = useState({ constructor_ref: "", name: "", country_id: "", wikipedia_url: "" });
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    try {
      await registerTeam({
        constructor_ref: form.constructor_ref,
        name: form.name,
        country_id: Number(form.country_id),
        wikipedia_url: form.wikipedia_url || null,
      });
      setSuccess(
        `Escuderia cadastrada. Usuário "${form.constructor_ref}_c" criado automaticamente (gatilho).`
      );
      setForm({ constructor_ref: "", name: "", country_id: "", wikipedia_url: "" });
      onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao cadastrar escuderia.");
    }
  }

  return (
    <Dialog open={open} onClose={onClose} title="Cadastrar nova escuderia">
      <form onSubmit={handleSubmit} className="space-y-3">
        <div className="space-y-1.5">
          <Label>Referência (constructor_ref)</Label>
          <Input
            value={form.constructor_ref}
            onChange={(e) => setForm({ ...form, constructor_ref: e.target.value })}
            placeholder="ex.: minha_escuderia"
            required
          />
        </div>
        <div className="space-y-1.5">
          <Label>Nome da escuderia</Label>
          <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
        </div>
        <div className="space-y-1.5">
          <Label>País</Label>
          <CountrySelect
            countries={countries}
            value={form.country_id}
            onChange={(v) => setForm({ ...form, country_id: v })}
          />
        </div>
        <div className="space-y-1.5">
          <Label>URL da Wikipédia (opcional)</Label>
          <Input
            value={form.wikipedia_url}
            onChange={(e) => setForm({ ...form, wikipedia_url: e.target.value })}
            placeholder="https://..."
          />
        </div>
        {error && <Alert variant="error">{error}</Alert>}
        {success && <Alert variant="success">{success}</Alert>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={onClose}>
            Fechar
          </Button>
          <Button type="submit">Cadastrar</Button>
        </div>
      </form>
    </Dialog>
  );
}

function RegisterDriverDialog({
  open,
  onClose,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const countries = useCountries(open);
  const [form, setForm] = useState({
    driver_ref: "",
    given_name: "",
    family_name: "",
    date_of_birth: "",
    country_id: "",
  });
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccess(null);
    try {
      await registerDriver({
        driver_ref: form.driver_ref,
        given_name: form.given_name,
        family_name: form.family_name,
        date_of_birth: form.date_of_birth || null,
        country_id: Number(form.country_id),
      });
      setSuccess(
        `Piloto cadastrado. Usuário "${form.driver_ref}_d" criado automaticamente (gatilho).`
      );
      setForm({ driver_ref: "", given_name: "", family_name: "", date_of_birth: "", country_id: "" });
      onSaved();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao cadastrar piloto.");
    }
  }

  return (
    <Dialog open={open} onClose={onClose} title="Cadastrar novo piloto">
      <form onSubmit={handleSubmit} className="space-y-3">
        <div className="space-y-1.5">
          <Label>Referência (driver_ref)</Label>
          <Input
            value={form.driver_ref}
            onChange={(e) => setForm({ ...form, driver_ref: e.target.value })}
            placeholder="ex.: novo_piloto"
            required
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <Label>Nome</Label>
            <Input
              value={form.given_name}
              onChange={(e) => setForm({ ...form, given_name: e.target.value })}
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label>Sobrenome</Label>
            <Input
              value={form.family_name}
              onChange={(e) => setForm({ ...form, family_name: e.target.value })}
              required
            />
          </div>
        </div>
        <div className="space-y-1.5">
          <Label>Data de nascimento</Label>
          <Input
            type="date"
            value={form.date_of_birth}
            onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })}
          />
        </div>
        <div className="space-y-1.5">
          <Label>País</Label>
          <CountrySelect
            countries={countries}
            value={form.country_id}
            onChange={(v) => setForm({ ...form, country_id: v })}
          />
        </div>
        {error && <Alert variant="error">{error}</Alert>}
        {success && <Alert variant="success">{success}</Alert>}
        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={onClose}>
            Fechar
          </Button>
          <Button type="submit">Cadastrar</Button>
        </div>
      </form>
    </Dialog>
  );
}
