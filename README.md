# F1 FIA Database — SCC-241 Final Project

Aplicação completa para exploração do banco de dados Formula 1 – FIA, com
três tipos de usuário (Administrador, Equipe e Piloto), dashboards,
relatórios e controle de acesso.

- **Backend:** Python + FastAPI + psycopg2 (SQL explícito, sem ORM) — pasta `backend/`
- **Frontend:** TypeScript + React + Tailwind CSS + componentes estilo shadcn/ui — pasta `frontend/`
- **Banco:** PostgreSQL (base `T1 work` restaurada a partir de `full_db.sql`)

---

## 1. Pré-requisitos

- **PostgreSQL** instalado e rodando em `localhost:5432`, com o papel (role) `postgres` disponível
  - As extensões `cube`, `earthdistance` e `pgcrypto` (pacote **contrib**) precisam estar disponíveis. Já vêm nos instaladores de Windows (EDB) e macOS (Postgres.app); no Ubuntu/Debian instale com `sudo apt install postgresql-contrib`. Sem elas a restauração de `full_db.sql` falha.
  - O dump cria a base com o locale `en_US.UTF-8`. Se o seu PostgreSQL não tiver esse locale (verifique com `locale -a`), edite a primeira linha de `full_db.sql` e troque `LOCALE = 'en_US.UTF-8'` por um locale UTF-8 disponível na máquina (ex.: `pt_BR.UTF-8` ou `C.UTF-8`). **Não** altere `ENCODING = 'UTF8'` — os dados estão gravados em UTF-8 e mudar a codificação corromperia os caracteres acentuados. Trocar apenas o locale afeta no máximo a ordem alfabética dos relatórios, não os dados.
- **Python 3.10+**
- **Node.js 18+**

As credenciais de conexão **não** ficam no código. Copie `.env.example` para
`.env` na raiz do projeto e preencha com as credenciais do PostgreSQL local
(base, usuário, senha, porta) e o `JWT_SECRET`. O `.env` é ignorado pelo git:

```bash
cp .env.example .env   # depois edite o .env com sua senha do postgres
```

O backend (`backend/db.py` e `backend/security.py`) lê esses valores
automaticamente via `python-dotenv`.

## 2. Restaurar o banco (uma única vez)

O arquivo `full_db.sql` (na raiz) é um dump **completo**: cria a base `T1 work`,
todo o esquema (tabelas, gatilhos, funções, views, índices) **e os dados**
(pilotos, corridas, resultados, aeroportos, usuários…). Para restaurar:

```bash
psql -U postgres -f full_db.sql
```

> Rode o comando conectado a qualquer base existente (ex.: `postgres`) — o
> próprio script executa `CREATE DATABASE "T1 work"`. Como o dump foi gerado com
> `--clean --if-exists`, ele dropa e recria a base se ela já existir, então pode
> ser reexecutado com segurança.

Isso é tudo que o banco precisa. **Não** é necessário rodar `setup_db.py` nesse
fluxo — o dump já contém o que aquele script aplicaria.

<details>
<summary>Alternativa: montar o banco a partir dos scripts (apenas esquema, sem dados)</summary>

`setup_db.py` aplica, em ordem, os arquivos de `backend/sql/` sobre uma base
`T1 work` **já existente e já com as tabelas de domínio** (drivers, races,
results, airports…). Útil para reaplicar só gatilhos/funções/views/índices, mas
**não** carrega dados nem cria as tabelas de domínio.

```bash
cd backend
pip install -r requirements.txt
python3 setup_db.py
```

| Script | Conteúdo |
|---|---|
| `01_users.sql` | Tabelas `USERS` e `USERS_LOG`; carga do admin, equipes e pilotos com senha bcrypt (pgcrypto) |
| `02_triggers.sql` | Gatilhos que sincronizam `DRIVERS`/`CONSTRUCTORS` → `USERS` e cancelam inserções com login duplicado |
| `03_functions.sql` | Funções armazenadas dos dashboards e relatórios (inclui Relatório 2 com earthdistance) |
| `04_views.sql` | Views dos dashboards e relatórios |
| `05_indexes.sql` | Índices, cada um justificado em comentário |

O script é idempotente: pode ser reexecutado sem erro.

</details>

## 3. Instalar dependências e executar o backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --port 8000
```

Documentação automática da API: http://localhost:8000/docs

## 4. Executar o frontend

```bash
cd frontend
npm install
npm run dev
```

Acesse a URL exibida no terminal (http://localhost:5173 — ou 5174 se a 5173
estiver ocupada). O dev server faz proxy de `/api` para o backend.

## 5. Resumo — subir tudo do zero no novo PC

```bash
# 1) Banco (uma vez)
psql -U postgres -f full_db.sql

# 2) Backend (terminal 1)
cd backend && pip install -r requirements.txt && uvicorn main:app --port 8000

# 3) Frontend (terminal 2)
cd frontend && npm install && npm run dev
```

## 6. Usuários de teste

| Tipo | Login | Senha | Exemplo |
|---|---|---|---|
| Administrador | `admin` | `admin` | — |
| Equipe | `<constructor_ref>_c` | `<constructor_ref>` | `mclaren_c` / `mclaren` |
| Piloto | `<driver_ref>_d` | `<driver_ref>` | `hamilton_d` / `hamilton` |

## 7. Funcionalidades por tipo de usuário

**Administrador** — totais de pilotos/equipes/temporadas; corridas, equipes e
pilotos da temporada mais recente com pontos; cadastro de equipes e pilotos
(usuário criado automaticamente por gatilho); Relatórios 1 (resultados por
status), 2 (aeroportos a até 100 km de cidades brasileiras) e 3 (hierárquico
de equipes/circuitos/corridas).

**Equipe** — vitórias, nº de pilotos e período com dados (funções
armazenadas); busca de piloto por sobrenome (apenas quem correu pela equipe);
inserção de pilotos por arquivo (`sample_drivers.txt` na raiz é um exemplo);
Relatórios 4 e 5.

**Piloto** — somente leitura: período com dados e desempenho por ano/circuito
(funções armazenadas); Relatórios 6 e 7.

## 8. Decisões relevantes

- **Senhas:** nunca em texto plano — hash bcrypt via `pgcrypto` (`crypt` + `gen_salt('bf')`), verificadas no próprio SQL do login.
- **Sessão:** JWT Bearer; o tipo do usuário é validado no servidor em todas as rotas (um Piloto não acessa rotas de Admin/Equipe).
- **Auditoria:** todo LOGIN/LOGOUT é registrado em `USERS_LOG`.
- **Associação piloto–equipe na inserção por arquivo:** optamos por **não** registrar associação explícita; no esquema relacional adotado, o vínculo piloto–equipe existe apenas via `RESULTS` (corridas disputadas). O novo piloto passa a existir em `DRIVERS`/`USERS` e será associado à equipe quando houver resultados.
- **Voltas de uma corrida:** exibimos `MAX(laps)` dos resultados (voltas completadas pelo vencedor), interpretado como o nº de voltas registrado da corrida.

## 9. Estrutura do código

```
backend/
├── main.py            # instancia FastAPI, CORS, registra routers
├── db.py              # pool de conexões psycopg2
├── security.py        # JWT + verificação de tipo de usuário
├── setup_db.py        # aplica os scripts SQL em ordem
├── routers/           # somente HTTP — nenhum SQL aqui
└── queries/           # todo o SQL da aplicação, explícito
frontend/src/
├── types/             # interfaces TypeScript da API
├── utils/             # helpers puros (formatação)
├── services/          # única camada que chama a API
└── components/
    ├── views/         # telas (Login, Dashboard, Relatórios)
    └── ui/            # primitivas de UI estilo shadcn
```
