# Query Analysis Report — SCC-241 Final Project

Analysis of every SQL query backing the application requirements. The query
layer lives in `backend/queries/*.py`, but most of the real SQL is in the
stored objects under `backend/sql/` (views in `04_views.sql`, functions in
`03_functions.sql`, triggers in `02_triggers.sql`, schema for USERS in
`01_users.sql`). Both layers are analyzed together, per requirement.

Scoring criterion: optimization and whether the chosen relational operations
(joins, subqueries, semi-joins, aggregations, window functions) are the most
accurate/efficient for the task on **PostgreSQL**. Index optimization is
explicitly **out of scope** here. Scores are 1–10.

Schema facts used for validation:
- `results.position` is `varchar(5)` → comparing to `'1'` (string) is correct.
- `results.points` is `numeric(10,2)`, `results.laps` is `integer`.
- `cities.latitude/longitude` and `airports.latitude_deg/longitude_deg` are `double precision`.
- `countries` has `code` (`char(2)`) and `nationality`.

---

## Requirement 1 — Manage Users

### 1.1 — USERS table (userid, login UNIQUE, password, type, original_id)
- **EN:** Create a USERS table with at least userid, login (unique), password, type, original_id. original_id = source record id; null for admin.
- **PT:** Criar tabela USERS com userid, login (único), password, type, original_id. original_id guarda o id do registro de origem; nulo para o admin.
- **Query/DDL:** `01_users.sql` creates `users` with `login ... UNIQUE`, `type ... CHECK (type IN ('Admin','Team','Driver'))`, `original_id INTEGER` nullable, `userid SERIAL PRIMARY KEY`.
- **Compliance:** All required attributes present; uniqueness enforced by a `UNIQUE` constraint (which also gives the index used by login lookups); type domain restricted by CHECK; original_id nullable for admin.
- **Score: 10** — Schema is exactly what is asked; constraints are the correct mechanism.

### 1.2 — Passwords stored protected (no plain text)
- **EN:** Passwords must be stored protected; if using the USERS table, not in plain text.
- **PT:** Senhas armazenadas de forma protegida; se via tabela USERS, nunca em texto plano.
- **Query:** Seed inserts use `crypt('admin', gen_salt('bf'))` (pgcrypto bcrypt). Verification (`auth_queries.authenticate`) compares with `password = crypt(%s, password)`.
- **Compliance:** bcrypt with random per-row salt; the stored value is a non-reversible hash; the candidate password is re-hashed with the stored salt inside the DBMS and compared — plaintext never reaches the table. This is the correct authentication pattern.
- **Score: 9** — Correct and idiomatic. Minor: bcrypt (`bf`) is the pgcrypto default rather than the statement-mentioned SCRAM-SHA-256, but SCRAM only applies to the "real DBMS users" path, which they explicitly did not take, so this is compliant.

### 1.3 — Each user has exactly one type ('Admin'/'Team'/'Driver')
- **EN/PT:** type restricted to the three values.
- **DDL:** `CHECK (type IN ('Admin','Team','Driver'))`.
- **Compliance:** Domain enforced at the table level — the most accurate mechanism.
- **Score: 10**

### 1.4 — Existing drivers/teams also registered in USERS
- **EN:** Drivers and teams already in the F1 DB must be registered in USERS following the login/password standard.
- **PT:** Pilotos e equipes já cadastrados devem constar em USERS seguindo o padrão de login/senha.
- **Query:** Two seed `INSERT ... SELECT` statements: `c.constructor_ref || '_c'` / hashed `constructor_ref`, and `d.driver_ref || '_d'` / hashed `driver_ref`, with `ON CONFLICT (login) DO NOTHING`.
- **Compliance:** Set-based backfill straight from CONSTRUCTORS/DRIVERS; login pattern and password rule honored; `ON CONFLICT` makes the script idempotent (re-runnable) without duplicating users.
- **Score: 9** — Clean, set-based, idempotent. The hashing is done per row by `gen_salt`, which is correct.

### 1.5 — Auto create/update USERS when a driver/team is created or modified
- **EN:** Whenever a driver/team is created or modified, the matching USERS record must be created/updated automatically.
- **PT:** Sempre que um piloto/equipe for criado ou alterado, o registro em USERS deve ser criado/atualizado automaticamente.
- **Query:** Four triggers in `02_triggers.sql`. AFTER INSERT on drivers/constructors inserts the user; AFTER UPDATE re-syncs login+password. The "ref changed" guard lives in the trigger's `WHEN (NEW.*_ref IS DISTINCT FROM OLD.*_ref)` clause, so the function isn't even invoked on unrelated edits. Duplicate-login handling is done by attempting the write and catching `unique_violation`, which is re-raised as a clear business-rule message.
- **Compliance:** Trigger-based synchronization is exactly the asked mechanism. The `WHEN` clause is null-safe and avoids needless re-hashing of the password on irrelevant updates. Uniqueness rests on the `UNIQUE(login)` constraint (non-deferrable, checked at the write), and the caught `unique_violation` both produces the friendly message and rolls back the source insert in the same transaction.
- **Score: 9** — Now race-free and idiomatic: the read-then-write (`EXISTS` then `INSERT`) TOCTOU window is gone, work is no longer duplicated against the constraint, and the update path skips no-op writes via `WHEN`. The only remaining stylistic note (not a defect): timing is `AFTER` rather than `BEFORE`, deliberately kept for safe ordering should `original_id` ever become a foreign key.

### 1.6 — USERS_LOG audit table (userid, action, timestamp)
- **EN:** Create USERS_LOG auditing LOGIN/LOGOUT with userid, action type, datetime.
- **PT:** Criar USERS_LOG auditando LOGIN/LOGOUT com userid, ação e data/hora.
- **Query:** DDL creates `users_log(log_id, userid FK, action CHECK IN ('LOGIN','LOGOUT'), action_at TIMESTAMP DEFAULT now())`. `auth_queries.log_action` does `INSERT INTO users_log (userid, action) VALUES (%s,%s)`.
- **Compliance:** All required columns; FK to users; action domain constrained; timestamp defaulted by the DBMS so the app cannot forge it.
- **Score: 9** — Minimal, correct insert; timestamp via `DEFAULT now()` is the right call.

---

## Requirement 2 — Tool Screen Flow (dashboard header identity)

The screen flow itself is UI, but Screen 2 requires the logged-in user's
name/identification to be resolved from the DB.

- **EN:** Show the logged-in user's name/identification (Admin label, team name, or driver full name).
- **PT:** Exibir o nome/identificação do usuário logado (rótulo Admin, nome da equipe, ou nome completo do piloto).
- **Query:** `auth_queries.get_display_info` — for Team: `SELECT name FROM constructors WHERE id=%s`; for Driver: `SELECT given_name || ' ' || family_name FROM drivers WHERE id=%s`; Admin short-circuits in Python.
- **Compliance:** Single-row primary-key lookups keyed by `original_id`; full-name concatenation matches the "driver's full name" requirement.
- **Score: 9** — PK equality lookups, the optimal access path. Admin avoids a needless query.

---

## Requirement 3 — Actions per user type

### 3.Admin.a — Register team (CONSTRUCTORS)
- **EN:** Form to insert a new CONSTRUCTORS tuple from constructor_ref, name, country_id, wikipedia_url.
- **PT:** Formulário para inserir nova tupla em CONSTRUCTORS com constructor_ref, name, country_id, wikipedia_url.
- **Query:** `admin_queries.insert_team` — `INSERT INTO constructors (...) SELECT %s,%s,COALESCE(c.nationality,c.name),%s,c.id FROM countries c WHERE c.id=%s RETURNING ...`.
- **Compliance:** Captures the four required fields; derives the legacy `NOT NULL nationality` from the chosen country (documented design decision); the `INSERT ... SELECT ... WHERE c.id=%s` both validates the FK target exists (returns no row → app raises) and supplies derived values in one statement; the USERS row is created by the trigger.
- **Score: 9** — Single round-trip insert that also validates the country; `RETURNING` avoids a follow-up SELECT. `COALESCE` is a sensible guard.

### 3.Admin.b — Register driver (DRIVERS)
- **EN:** Form to insert a new driver from driver_ref, given_name, family_name, date_of_birth, country_id.
- **PT:** Formulário para inserir piloto com driver_ref, given_name, family_name, date_of_birth, country_id.
- **Query:** `admin_queries.insert_driver` — mirror of insert_team against DRIVERS.
- **Compliance:** Same pattern; trigger creates the USERS row; duplicate generated login aborts via the trigger's `RAISE`.
- **Score: 9** — Same strengths as 3.Admin.a.

### 3.Admin.c — Duplicate generated login cancels source insert
- **EN/PT:** If the generated login already exists, the trigger must cancel the operation and prevent inconsistent insertion.
- **Query:** Inside `fn_sync_user_after_*_insert`: the `INSERT INTO users` is attempted and `EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION '...cancelada.'` translates a duplicate login into a clear message.
- **Compliance:** The `UNIQUE(login)` constraint is checked at the moment of the user insert (non-deferrable); the caught `unique_violation` re-raises, rolling back the whole transaction (same statement that inserted the driver/team), so the source row is not persisted — exactly the requested behavior, and now without the prior read-then-write race.
- **Score: 9**

### 3.Team.a — Query driver by last name (only drivers who raced for the team)
- **EN:** Given a surname, find drivers with that surname who raced for the logged-in team; show full name, DOB, country/nationality. (Check via RESULTS.)
- **PT:** Dado um sobrenome, encontrar pilotos que correram pela equipe logada; mostrar nome completo, data de nascimento e país/nacionalidade. (Verificar via RESULTS.)
- **Query:** `team_queries.find_drivers_by_surname` — `... FROM drivers d LEFT JOIN countries co ... WHERE LOWER(d.family_name)=LOWER(%s) AND EXISTS (SELECT 1 FROM results r WHERE r.driver_id=d.id AND r.constructor_id=%s)`.
- **Compliance:** Uses an **EXISTS semi-join** on RESULTS to test "raced for this team" — the most accurate operator (stops at first match, no row multiplication, no need for DISTINCT). LEFT JOIN to countries so a driver with null country still appears (falls back to `nationality`). Case-insensitive surname match.
- **Score: 9** — Semi-join is the textbook-correct choice here. `LOWER()` on the column would bypass a plain B-tree index, but the code comments reference a functional `lower(family_name)` index, which is the right answer (out of scope for scoring).

### 3.Team.b — Insert drivers from file, rejecting duplicate full names
- **EN:** Insert one or more drivers from a file; before insertion verify no driver with the same first+last name exists, else report and cancel.
- **PT:** Inserir pilotos de um arquivo; antes verificar que não há piloto com mesmo nome e sobrenome, senão avisar e cancelar.
- **Query:** `team_queries.driver_name_exists` — `SELECT 1 FROM drivers WHERE LOWER(given_name)=LOWER(%s) AND LOWER(family_name)=LOWER(%s)`; then `team_queries.insert_driver_from_file` (same INSERT...SELECT pattern; trigger creates the user). Orchestrated per line in `routers/team.py` (`POST /api/team/drivers/upload`).
- **Compliance:** The pre-check implements the "no duplicate full name" rule (case-insensitive, stricter/safer than the literal requirement); `SELECT 1 ... fetchone is not None` is the cheapest existence test. The insert reuses the validated country pattern and relies on the trigger for the USERS row. The router processes each line independently and, because `db_cursor()` commits per call, **each line is its own transaction** — a failed line rolls back only itself while valid lines stay committed (true "cancel just this driver" semantics). It reports a precise per-line error taxonomy: wrong field count, bad `country_id`, duplicate full name, trigger rejection (duplicate `driver_ref` login → friendly message), `driver_ref` unique violation, invalid date, missing country; returning both `inserted` and `errors`. Intra-file duplicates are also caught, since each accepted line commits before the next is checked.
- **Score: 8** — Correct, minimal, and the surrounding flow handles edge cases the statement doesn't strictly demand. Notes: (1) the existence check and the insert are two separate statements/transactions (a tiny TOCTOU window, irrelevant for this single-user prototype); (2) the full-name check is an **application-level rule scoped to this feature only** — correctly *not* applied to the Admin `insert_driver` path (3.Admin.b doesn't require it), which is why a global `UNIQUE(full name)` constraint would be the wrong tool; (3) per the statement, recording the new driver↔team association is optional — they did **not** create a RESULTS link (correct domain modeling: a driver's team is historical, expressed only via RESULTS), so a file-inserted driver won't be found by 3.Team.a for this team until they have a result. Worth stating in the written report. (4) Optional polish: line parsing uses `str.split(',')`, which assumes comma-free fields — document this assumption or switch to the `csv` module.

### 3.Driver — Read-only
- **EN/PT:** Driver users cannot alter data; only view reports/dashboard.
- **Query:** `driver_queries.py` contains **only** parameterized SELECTs, all keyed by the driver's own id.
- **Compliance:** No write paths exist for drivers; scope is enforced by the `driver_id` parameter on every query.
- **Score: 9**

---

## Requirement 4 — Dashboards

### 4.Admin.1 — Totals of drivers, teams, seasons
- **EN/PT:** Total number of drivers, teams and seasons registered.
- **Query:** `admin_queries.get_dashboard` first statement: three scalar subqueries `(SELECT COUNT(*) FROM drivers/constructors/seasons)` in a single row.
- **Compliance:** Returns the three counts in one round-trip.
- **Score: 9** — Combining three counts into one statement avoids three round-trips. Each `COUNT(*)` is an unavoidable scan/index-only scan; the formulation is optimal for the requirement.

### 4.Admin.2 — Races of the most recent season (circuit, date, time, laps)
- **EN/PT:** List races of the most recent season with circuit, date, time and number of laps recorded in results.
- **Query:** `vw_latest_season_races` — `races JOIN vw_latest_season JOIN circuits LEFT JOIN results`, `MAX(r.laps) AS laps`, grouped per race, `ORDER BY round`. `vw_latest_season` = `seasons ORDER BY year DESC LIMIT 1`.
- **Compliance:** "Most recent season" via `ORDER BY year DESC LIMIT 1` (correct). `MAX(laps)` per race = laps completed by the leader = the race's recorded lap count, a reasonable interpretation of "number of laps recorded in the results". LEFT JOIN keeps races with no results rows.
- **Score: 8** — Sound. `MAX(laps)` is a defensible reading of an ambiguous requirement; if the grader expects the *winner's* laps specifically it is still correct since the winner completes the most laps. The view is reused cleanly for the latest-season selection.

### 4.Admin.3 — Teams of the most recent season with total points
- **EN/PT:** List teams that competed in the most recent season, each with total points.
- **Query:** `vw_latest_season_team_points` — `results JOIN races JOIN vw_latest_season JOIN constructors`, `COALESCE(SUM(points),0)`, grouped per team, ordered by points desc.
- **Compliance:** Joins restrict to the latest season; SUM aggregates points per team; only teams with results in that season appear, which matches "competed". `COALESCE` guards null sums.
- **Score: 9** — Correct join chain and aggregation; ordering aids readability as recommended.

### 4.Admin.4 — Drivers of the most recent season with total points
- **EN/PT:** List drivers that competed in the most recent season, each with total points.
- **Query:** `vw_latest_season_driver_points` — analogous to 4.Admin.3 against DRIVERS.
- **Compliance:** Same correct pattern; full-name concatenation for display.
- **Score: 9**

### 4.Team.1 — Number of wins (first positions)
- **EN/PT:** Number of wins for the team (races finished in 1st position), via a stored function receiving team data.
- **Query:** `fn_team_wins(p_constructor_id)` — `SELECT COUNT(*) FROM results WHERE constructor_id=p AND position='1'`.
- **Compliance:** Stored function taking the team id (as required); counts first-place finishes; `position='1'` correct given the varchar column.
- **Score: 9** — Direct, single-table filtered aggregation; the most accurate form.

### 4.Team.2 — Number of distinct drivers for the team
- **EN/PT:** Number of different drivers who raced for the team.
- **Query:** `fn_team_driver_count` — `COUNT(DISTINCT driver_id) FROM results WHERE constructor_id=p`.
- **Compliance:** `COUNT(DISTINCT)` is exactly "different drivers".
- **Score: 9**

### 4.Team.3 — First and last year with team data (via RESULTS)
- **EN/PT:** First and last year for which there is team data, considering RESULTS.
- **Query:** `fn_team_active_years` — `MIN(s.year), MAX(s.year) FROM results JOIN races JOIN seasons WHERE constructor_id=p`.
- **Compliance:** Joins RESULTS→races→seasons and takes MIN/MAX year — the correct way to derive the active span from RESULTS.
- **Score: 9.** The team dashboard (`team_queries.get_dashboard`) calls all three functions in **one** statement (`SELECT fn_team_wins(...), fn_team_driver_count(...), ... FROM fn_team_active_years(...)`), saving round-trips. Trade-off: the three functions each scan `results` filtered by `constructor_id` separately rather than in a single pass, but the statement requires *separate* stored functions, so this is the intended design. Functions are correctly marked `STABLE`.

### 4.Driver.1 — First and last year with driver data (via RESULTS)
- **EN/PT:** First and last year for which there is driver data, considering RESULTS.
- **Query:** `fn_driver_active_years` — MIN/MAX year over `results JOIN races JOIN seasons WHERE driver_id=p`.
- **Compliance:** Same correct MIN/MAX-over-joins pattern, scoped to the driver.
- **Score: 9**

### 4.Driver.2 — Per year and per circuit: points, wins, total races
- **EN/PT:** For each year and each circuit the driver raced: points obtained, wins (1st positions), total races participated.
- **Query:** `fn_driver_yearly_circuit_stats` — `results JOIN races JOIN seasons JOIN circuits WHERE driver_id=p GROUP BY year, circuit`, with `COALESCE(SUM(points),0)`, `COUNT(*) FILTER (WHERE position='1')` for wins, `COUNT(*)` for races.
- **Compliance:** Two-level grouping (year, circuit) matches the requirement exactly; `FILTER` cleanly separates wins from total races in a single scan (the most efficient PostgreSQL idiom — no self-join or correlated subquery).
- **Score: 9** — `FILTER`-based conditional aggregation is the optimal approach here.

Note: `driver_queries.get_dashboard` also resolves the driver's most recent team
via a correlated subquery (`results JOIN races JOIN constructors ORDER BY
race_date DESC NULLS LAST LIMIT 1`). This is the right "latest row" pattern;
`NULLS LAST` correctly keeps undated races from being treated as most recent.

---

## Requirement 5 — Reports

### Report 1 (Admin) — Results count by status
- **EN/PT:** Number of results by status: status name and its count.
- **Query:** `vw_results_by_status` — `results JOIN status GROUP BY status`, `COUNT(*)`, ordered by total desc.
- **Compliance:** Single join + group-by + count, the canonical formulation; ordering aids interpretation.
- **Score: 9**

### Report 2 (Admin) — Brazilian airports within 100 km of a named Brazilian city
- **EN:** For each Brazilian city with the given name, list Brazilian medium/large airports ≤100 km away; show city name, IATA, airport name, airport city, distance, type.
- **PT:** Para cada cidade brasileira com o nome dado, listar aeroportos brasileiros medium/large a ≤100 km; mostrar nome da cidade, IATA, nome do aeroporto, cidade do aeroporto, distância e tipo.
- **Query:** `fn_report2_airports_near_city(p_city_name)` — joins `cities` (BR, name match) to `airports` using `earth_box(ll_to_earth(city), 100000) @> ll_to_earth(airport)` as a bounding-box pre-filter **plus** `earth_distance(...) <= 100000` for the exact radius, joins `airport_types` filtered to medium/large, LEFT JOINs the airport's city/country, returns distance in km, ordered by city then distance.
- **Compliance:** Implements the earth-distance radius correctly. The `earth_box ... @>` predicate is GiST-indexable and prunes candidates before the exact `earth_distance` check — the recommended two-stage spatial pattern. The BR filters on both the searched city (`pc.code='BR'`) and the airport (`apc.code='BR' OR a.city_id IS NULL`) honor "Brazilian airports". All six output columns are produced.
- **Score: 8** — Strong, idiomatic spatial query. Deduction: `ll_to_earth`/`earth_distance` are computed up to three times per candidate pair (box predicate, the `<=` predicate, and the `ROUND` in SELECT); a lateral/sub-select computing the earth points once would cut redundant work. Also `a.city_id IS NULL` lets a city-less airport of unknown country slip through — a minor correctness edge.

### Report 3 (Admin) — Teams w/ driver counts + 3-level hierarchical race report
- **EN/PT:** All teams with their driver counts; plus a 3-level report: (1) total races; (2) races per circuit with min/avg/max laps; (3) per race per circuit, laps recorded and number of participating drivers.
- **Query:** `admin_queries.report3_hierarchical`:
  - `vw_teams_driver_count` — `constructors LEFT JOIN results`, `COUNT(DISTINCT driver_id)` (LEFT JOIN so 0-driver teams still appear).
  - Level 1: `COUNT(*) FROM races`.
  - Level 2: `circuits JOIN races LEFT JOIN results GROUP BY circuit`, `COUNT(DISTINCT race)`, `MIN/ROUND(AVG,1)/MAX(laps)`.
  - Level 3: `races JOIN seasons LEFT JOIN results GROUP BY race`, `MAX(laps)`, `COUNT(DISTINCT driver_id)`, ordered by circuit then year.
- **Compliance:** Each of the three levels is produced by the appropriate aggregation; `COUNT(DISTINCT race)` at level 2 avoids inflation from the results join; `COUNT(DISTINCT driver_id)` at level 3 gives "participating drivers"; LEFT JOINs preserve races/circuits without results. The driver-count list is delivered alongside.
- **Score: 8** — Correct and well-structured. The three levels are independent statements rather than one rollup; `GROUPING SETS`/`ROLLUP` could express the hierarchy in a single pass, but the separate-query approach is clearer and equally correct for the data sizes here.

### Report 4 (Team) — Drivers and number of first-place finishes for the team
- **EN/PT:** List the team's drivers and how many times each finished 1st, by full name. (Via RESULTS.)
- **Query:** `fn_report4_team_driver_wins(p_constructor_id)` — `results JOIN drivers WHERE constructor_id=p GROUP BY driver`, `COUNT(*) FILTER (WHERE position='1')` as wins, ordered by wins desc.
- **Compliance:** Stored function receiving the team id (as recommended); join to DRIVERS for the full name; conditional `FILTER` aggregation counts wins in a single scan; grouping by driver lists each driver of the team (including those with 0 wins who have results rows).
- **Score: 9** — `FILTER` is the optimal way to count wins while still listing all drivers; ordering by wins is good UX.

### Report 5 (Team) — Results by status within the team scope
- **EN/PT:** Number of results by status, limited to the logged-in team.
- **Query:** `fn_report5_team_status_counts(p_constructor_id)` — `results JOIN status WHERE constructor_id=p GROUP BY status`.
- **Compliance:** Report 1's shape with the `constructor_id` filter applied before grouping — exactly "limited to the team scope".
- **Score: 9**

### Report 6 (Driver) — Points per year with the races where points were obtained
- **EN/PT:** Total points per year of participation, showing for each year the races where points were obtained; restricted to the logged-in driver.
- **Query:** `fn_report6_driver_points_by_year(p_driver_id)` — `results JOIN races JOIN seasons WHERE driver_id=p AND points>0`, with `SUM(points) OVER (PARTITION BY year) AS year_total`, ordered by year, date.
- **Compliance:** Returns each point-scoring race **and** the per-year total in one pass via a **window function** — no second query/self-join needed. `points>0` selects "races in which points were obtained"; the whole thing is scoped to the driver.
- **Score: 9** — Window aggregation is the most accurate and efficient way to attach the yearly total to each detail row. (`year_total` consistently sums only point-scoring races, matching the filter.)

### Report 7 (Driver) — Results by status within the driver scope
- **EN/PT:** Number of results by status in the driver's races, limited to the logged-in driver.
- **Query:** `fn_report7_driver_status_counts(p_driver_id)` — `results JOIN status WHERE driver_id=p GROUP BY status`.
- **Compliance:** Report 1's shape scoped by `driver_id`.
- **Score: 9**

---

## Indexes (`backend/sql/05_indexes.sql`)

Context: PostgreSQL automatically indexes primary keys and `UNIQUE` constraints,
but **not** foreign-key columns. The base schema already provides, among others,
`uq_results_race_driver UNIQUE (race_id, driver_id)` and
`uq_races_season_round UNIQUE (season_id, round)` (both usable as B-tree indexes
on their leading column). The eight indexes below add what the app's filters,
joins and sorts actually need.

### idx_results_constructor — `results (constructor_id)`
- **Serves:** every team-scoped query (`WHERE r.constructor_id = $1`): team dashboard `fn_team_*`, `find_drivers_by_surname` (EXISTS), Reports 4 & 5. Satisfies the statement's "necessary indexes" mandate for **Report 4**.
- **Assessment:** `constructor_id` is an unindexed FK; without this every team query is a full scan of RESULTS (the largest table). Correct column, correct type (B-tree equality).
- **Score: 10**

### idx_results_driver — `results (driver_id)`
- **Serves:** every driver-scoped query (`WHERE r.driver_id = $1`): driver dashboard, `fn_driver_*`, Reports 6 & 7, and the "most recent team" correlated subquery. Satisfies the "necessary indexes" mandate for **Report 6**.
- **Assessment:** Same rationale as above on the driver FK. Essential.
- **Score: 10**

### idx_results_status — `results (status_id)`
- **Serves:** the `results → status` join + `GROUP BY status` of Reports 1, 5, 7.
- **Assessment:** Weakest of the set, but defensible. For **Report 1** (`COUNT(*) per status` over *all* results) it can enable a narrower index(-only) scan instead of a full heap scan to compute the grouping. For **Reports 5/7** it is largely redundant: those already filter by `constructor_id`/`driver_id` (other indexes) and then resolve the status name by `status.id` PK, so the planner likely won't use this index there. Harmless, low marginal value.
- **Score: 6**

### idx_airports_earth — `airports USING gist (ll_to_earth(latitude_deg, longitude_deg))`
- **Serves:** **Report 2** — explicitly required by the statement ("An index must also be created to assist this query").
- **Assessment:** Exactly right. The `earth_box(...) @> ll_to_earth(...)` containment operator can only use an index if a **GiST** index exists over `ll_to_earth(lat, lon)`; this is what prunes airports to the 100 km bounding box before the exact `earth_distance` refinement. Correct access method (GiST, not B-tree) and correct expression.
- **Score: 10**

### idx_cities_country_lower_name — `cities (country_id, LOWER(name))`
- **Serves:** **Report 2**'s city lookup (`ci.country_id = <BR> AND LOWER(ci.name) = LOWER($1)`).
- **Assessment:** Well-matched composite functional index: the planner can resolve Brazil's `country_id` from `countries` (unique on `code`) and probe cities by both keyed columns, turning a full `cities` scan + per-row `LOWER()` into an index probe. Column order (selective `country_id` first, then `lower(name)`) is sensible. Note the base schema's `idx_cities_name_pattern (name text_pattern_ops)` serves `LIKE` prefix search, **not** this case-insensitive equality, so the new index is genuinely needed.
- **Score: 9**

### idx_drivers_family_name_lower — `drivers (LOWER(family_name))`
- **Serves:** the Team "query driver by surname" action (`WHERE LOWER(d.family_name) = LOWER($1)`); also assists the file-import duplicate check (`LOWER(family_name)` half of the predicate).
- **Assessment:** Functional index that matches the case-insensitive predicate exactly — without it the `LOWER()` call forces a full scan. The base schema's `idx_drivers_name_hash` (hash over the *case-sensitive* `given||' '||family` concatenation) does **not** serve either of the app's `LOWER()`-based queries, so this index is the correct addition.
- **Score: 9**

### Requirement-mandated indexes — all present
- **Report 2** → `idx_airports_earth` (+ `idx_cities_country_lower_name`). ✅
- **Report 4** → `idx_results_constructor`. ✅
- **Report 6** → `idx_results_driver`. ✅

### Remaining gaps (optional)
- **Possible small gap:** Report 3 level 2 joins `races` by `circuit_id` (`fk_races_circuit`, unindexed); an `idx_races_circuit` would help, though `races` is small enough that a scan is cheap — optional.
- **Pre-existing but unused by the app:** `idx_drivers_name_hash` and `idx_cities_name_pattern` come from the base dump and don't match the app's `LOWER()` predicates; not this project's responsibility, just noted.

### Index analysis — overall
The set is lean and fully justifiable: the FK filters on RESULTS that drive
nearly every scoped query, the GiST spatial index required for Report 2, and the
two functional indexes matching the `LOWER()` predicates — plus
`idx_results_status` for Report 1's grouping. Type/column choices are appropriate
for PostgreSQL and every index has a real consumer. **Index suite score: 9/10.**

## Summary table

| Requirement | Object | Score |
|---|---|---|
| 1.1 USERS table | DDL | 10 |
| 1.2 Protected passwords | crypt/bcrypt | 9 |
| 1.3 type domain | CHECK | 10 |
| 1.4 Backfill USERS | seed INSERT...SELECT | 9 |
| 1.5 Auto-sync triggers | 4 triggers | 9 |
| 1.6 USERS_LOG | DDL + log_action | 9 |
| 2 Dashboard identity | get_display_info | 9 |
| 3.Admin register team | insert_team | 9 |
| 3.Admin register driver | insert_driver | 9 |
| 3.Admin dup-login cancel | trigger RAISE | 9 |
| 3.Team query by surname | EXISTS semi-join | 9 |
| 3.Team insert by file | driver_name_exists + insert | 8 |
| 3.Driver read-only | SELECT-only module | 9 |
| 4.Admin.1 totals | scalar subqueries | 9 |
| 4.Admin.2 latest races | vw_latest_season_races | 8 |
| 4.Admin.3 team points | vw_latest_season_team_points | 9 |
| 4.Admin.4 driver points | vw_latest_season_driver_points | 9 |
| 4.Team.1 wins | fn_team_wins | 9 |
| 4.Team.2 distinct drivers | fn_team_driver_count | 9 |
| 4.Team.3 active years | fn_team_active_years | 9 |
| 4.Driver.1 active years | fn_driver_active_years | 9 |
| 4.Driver.2 yearly/circuit | fn_driver_yearly_circuit_stats | 9 |
| Report 1 status counts | vw_results_by_status | 9 |
| Report 2 airports | fn_report2_airports_near_city | 8 |
| Report 3 hierarchical | report3_hierarchical | 8 |
| Report 4 driver wins | fn_report4_team_driver_wins | 9 |
| Report 5 team status | fn_report5_team_status_counts | 9 |
| Report 6 points by year | fn_report6_driver_points_by_year | 9 |
| Report 7 driver status | fn_report7_driver_status_counts | 9 |

### Index summary

| Index | Target | Serves | Score |
|---|---|---|---|
| idx_results_constructor | results(constructor_id) | team scope, Report 4 | 10 |
| idx_results_driver | results(driver_id) | driver scope, Report 6 | 10 |
| idx_results_status | results(status_id) | status grouping (R1) | 6 |
| idx_airports_earth | gist ll_to_earth(airports) | Report 2 (required) | 10 |
| idx_cities_country_lower_name | cities(country_id, lower(name)) | Report 2 city lookup | 9 |
| idx_drivers_family_name_lower | drivers(lower(family_name)) | surname search / name check | 9 |

**Index suite: 9/10** — lean set, every index has a real consumer.

**Overall:** The query layer is consistently high quality. Strong points:
correct use of semi-joins (`EXISTS`), conditional aggregation (`COUNT(*) FILTER`),
window functions (`SUM() OVER`), set-based inserts with `RETURNING`, and the
two-stage `earth_box` + `earth_distance` spatial pattern, and race-free trigger
synchronization that translates `unique_violation` into clear messages while
guarding no-op updates with a `WHEN` clause. The few remaining deductions are
about redundant geo computations (Report 2) and the optional driver↔team
association not being recorded on file insert — none of which are correctness
failures.
