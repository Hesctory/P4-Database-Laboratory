-- ============================================================================
-- 03_functions.sql — Funções armazenadas para dashboards e relatórios
-- SCC-241 Final Project
--
-- CONCEITO: Procedures/Funções armazenadas.
-- O enunciado exige funções que recebam o identificador da equipe/piloto
-- como parâmetro e retornem as informações do dashboard e dos relatórios.
-- Centralizar a lógica no banco evita repetição de SQL na aplicação e
-- mantém os comandos explícitos e analisáveis.
-- ============================================================================

-- cube + earthdistance: cálculo de distância geográfica (Relatório 2).
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;

-- ============================================================================
-- DASHBOARD DA EQUIPE
-- ============================================================================

-- Número de vitórias da equipe (corridas em que obteve a 1ª posição).
-- Agregação COUNT com filtro sobre RESULTS.
CREATE OR REPLACE FUNCTION fn_team_wins(p_constructor_id INTEGER)
RETURNS BIGINT AS $$
    SELECT COUNT(*)
    FROM results r
    WHERE r.constructor_id = p_constructor_id
      AND r.position = '1';
$$ LANGUAGE sql STABLE;

-- Número de pilotos distintos que já correram pela equipe.
CREATE OR REPLACE FUNCTION fn_team_driver_count(p_constructor_id INTEGER)
RETURNS BIGINT AS $$
    SELECT COUNT(DISTINCT r.driver_id)
    FROM results r
    WHERE r.constructor_id = p_constructor_id;
$$ LANGUAGE sql STABLE;

-- Primeiro e último ano com dados da equipe em RESULTS
-- (JOIN results → races → seasons + agregações MIN/MAX).
CREATE OR REPLACE FUNCTION fn_team_active_years(p_constructor_id INTEGER)
RETURNS TABLE (first_year INTEGER, last_year INTEGER) AS $$
    SELECT MIN(s.year), MAX(s.year)
    FROM results r
    JOIN races   ra ON ra.id = r.race_id
    JOIN seasons s  ON s.id  = ra.season_id
    WHERE r.constructor_id = p_constructor_id;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- DASHBOARD DO PILOTO
-- ============================================================================

-- Primeiro e último ano com dados do piloto em RESULTS.
CREATE OR REPLACE FUNCTION fn_driver_active_years(p_driver_id INTEGER)
RETURNS TABLE (first_year INTEGER, last_year INTEGER) AS $$
    SELECT MIN(s.year), MAX(s.year)
    FROM results r
    JOIN races   ra ON ra.id = r.race_id
    JOIN seasons s  ON s.id  = ra.season_id
    WHERE r.driver_id = p_driver_id;
$$ LANGUAGE sql STABLE;

-- Por ano e por circuito em que o piloto correu: pontos, vitórias e corridas.
-- JOIN + GROUP BY em dois níveis (ano, circuito), com agregações SUM e COUNT.
CREATE OR REPLACE FUNCTION fn_driver_yearly_circuit_stats(p_driver_id INTEGER)
RETURNS TABLE (
    year         INTEGER,
    circuit_name TEXT,
    points       NUMERIC,
    wins         BIGINT,
    races        BIGINT
) AS $$
    SELECT s.year,
           c.name,
           COALESCE(SUM(r.points), 0)                AS points,
           COUNT(*) FILTER (WHERE r.position = '1')  AS wins,
           COUNT(*)                                  AS races
    FROM results r
    JOIN races    ra ON ra.id = r.race_id
    JOIN seasons  s  ON s.id  = ra.season_id
    JOIN circuits c  ON c.id  = ra.circuit_id
    WHERE r.driver_id = p_driver_id
    GROUP BY s.year, c.name
    ORDER BY s.year, c.name;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- RELATÓRIO 2 (Admin) — Aeroportos brasileiros a até 100 km de cada cidade
-- brasileira com o nome pesquisado, apenas 'medium_airport'/'large_airport'.
--
-- earth_box() pré-filtra por uma caixa delimitadora que PODE usar o índice
-- GiST criado em 05_indexes.sql; earth_distance() refina o cálculo exato.
-- A distância é retornada em km.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_report2_airports_near_city(p_city_name TEXT)
RETURNS TABLE (
    city_name    VARCHAR,
    iata_code    VARCHAR,
    airport_name TEXT,
    airport_city VARCHAR,
    distance_km  NUMERIC,
    airport_type VARCHAR
) AS $$
    SELECT ci.name,
           a.iata_code,
           a.name,
           ac.name,
           ROUND((earth_distance(
                    ll_to_earth(ci.latitude, ci.longitude),
                    ll_to_earth(a.latitude_deg, a.longitude_deg)) / 1000.0)::numeric, 2) AS distance_km,
           t.type
    FROM cities ci
    JOIN countries pc ON pc.id = ci.country_id AND pc.code = 'BR'   -- cidade brasileira
    JOIN airports a
      ON earth_box(ll_to_earth(ci.latitude, ci.longitude), 100000)  -- 100 km em metros
         @> ll_to_earth(a.latitude_deg, a.longitude_deg)
     AND earth_distance(ll_to_earth(ci.latitude, ci.longitude),
                        ll_to_earth(a.latitude_deg, a.longitude_deg)) <= 100000
    JOIN airport_types t ON t.id = a.airport_type_id
                        AND t.type IN ('medium_airport', 'large_airport')
    LEFT JOIN cities    ac  ON ac.id = a.city_id
    LEFT JOIN countries apc ON apc.id = ac.country_id
    WHERE LOWER(ci.name) = LOWER(p_city_name)
      AND (apc.code = 'BR' OR a.city_id IS NULL)                    -- aeroporto brasileiro
    ORDER BY ci.id, distance_km;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- RELATÓRIO 4 (Equipe) — Pilotos da equipe e nº de vezes em 1º lugar
-- correndo por ela. Identificados pelo nome completo.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_report4_team_driver_wins(p_constructor_id INTEGER)
RETURNS TABLE (full_name TEXT, wins BIGINT) AS $$
    SELECT d.given_name || ' ' || d.family_name AS full_name,
           COUNT(*) FILTER (WHERE r.position = '1') AS wins
    FROM results r
    JOIN drivers d ON d.id = r.driver_id
    WHERE r.constructor_id = p_constructor_id
    GROUP BY d.id, d.given_name, d.family_name
    ORDER BY wins DESC, full_name;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- RELATÓRIO 5 (Equipe) — Resultados por status, no escopo da equipe.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_report5_team_status_counts(p_constructor_id INTEGER)
RETURNS TABLE (status TEXT, total BIGINT) AS $$
    SELECT st.status, COUNT(*) AS total
    FROM results r
    JOIN status st ON st.id = r.status_id
    WHERE r.constructor_id = p_constructor_id
    GROUP BY st.status
    ORDER BY total DESC, st.status;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- RELATÓRIO 6 (Piloto) — Pontos por ano, mostrando as corridas em que os
-- pontos foram obtidos. A função de janela SUM() OVER (PARTITION BY ano)
-- fornece o total anual sem precisar de uma segunda consulta.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_report6_driver_points_by_year(p_driver_id INTEGER)
RETURNS TABLE (
    year        INTEGER,
    race_name   TEXT,
    race_date   DATE,
    points      NUMERIC,
    year_total  NUMERIC
) AS $$
    SELECT s.year,
           ra.race_name,
           ra.race_date,
           r.points,
           SUM(r.points) OVER (PARTITION BY s.year) AS year_total
    FROM results r
    JOIN races   ra ON ra.id = r.race_id
    JOIN seasons s  ON s.id  = ra.season_id
    WHERE r.driver_id = p_driver_id
      AND r.points > 0                 -- corridas em que os pontos foram obtidos
    ORDER BY s.year, ra.race_date;
$$ LANGUAGE sql STABLE;

-- ============================================================================
-- RELATÓRIO 7 (Piloto) — Resultados por status, no escopo do piloto.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_report7_driver_status_counts(p_driver_id INTEGER)
RETURNS TABLE (status TEXT, total BIGINT) AS $$
    SELECT st.status, COUNT(*) AS total
    FROM results r
    JOIN status st ON st.id = r.status_id
    WHERE r.driver_id = p_driver_id
    GROUP BY st.status
    ORDER BY total DESC, st.status;
$$ LANGUAGE sql STABLE;
