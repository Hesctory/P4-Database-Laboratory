-- ============================================================================
-- 04_views.sql — Views compartilhadas entre dashboards e relatórios
-- SCC-241 Final Project
--
-- CONCEITO: Views.
-- Consultas com JOINs/agregações reutilizadas em mais de um ponto da
-- aplicação são materializadas como views, evitando duplicação de SQL e
-- deixando a intenção de cada consulta nomeada e documentada.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Contagem de resultados por status (Relatório 1 do Admin).
-- A mesma estrutura é usada, com filtro adicional, nos Relatórios 5 e 7.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_results_by_status AS
SELECT st.status,
       COUNT(*) AS total
FROM results r
JOIN status st ON st.id = r.status_id
GROUP BY st.status
ORDER BY total DESC, st.status;

-- ----------------------------------------------------------------------------
-- Temporada mais recente registrada no banco.
-- Base dos três blocos do dashboard do Admin (corridas, equipes e pilotos
-- da última temporada).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_latest_season AS
SELECT s.id, s.year
FROM seasons s
ORDER BY s.year DESC
LIMIT 1;

-- ----------------------------------------------------------------------------
-- Corridas da temporada mais recente, com circuito, data, hora e número de
-- voltas registrado nos resultados (MAX(laps) = voltas completadas pelo
-- vencedor, ou seja, a duração registrada da corrida).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_latest_season_races AS
SELECT ra.id,
       ra.round,
       ra.race_name,
       c.name AS circuit_name,
       ra.race_date,
       ra.race_time,
       MAX(r.laps) AS laps
FROM races ra
JOIN vw_latest_season ls ON ls.id = ra.season_id
JOIN circuits c ON c.id = ra.circuit_id
LEFT JOIN results r ON r.race_id = ra.id
GROUP BY ra.id, ra.round, ra.race_name, c.name, ra.race_date, ra.race_time
ORDER BY ra.round;

-- ----------------------------------------------------------------------------
-- Equipes que disputaram a temporada mais recente, com total de pontos.
-- JOIN results → races (filtrado pela última temporada) + SUM agregado.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_latest_season_team_points AS
SELECT co.id,
       co.name AS team_name,
       COALESCE(SUM(r.points), 0) AS total_points
FROM results r
JOIN races ra ON ra.id = r.race_id
JOIN vw_latest_season ls ON ls.id = ra.season_id
JOIN constructors co ON co.id = r.constructor_id
GROUP BY co.id, co.name
ORDER BY total_points DESC, team_name;

-- ----------------------------------------------------------------------------
-- Pilotos que disputaram a temporada mais recente, com total de pontos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_latest_season_driver_points AS
SELECT d.id,
       d.given_name || ' ' || d.family_name AS driver_name,
       COALESCE(SUM(r.points), 0) AS total_points
FROM results r
JOIN races ra ON ra.id = r.race_id
JOIN vw_latest_season ls ON ls.id = ra.season_id
JOIN drivers d ON d.id = r.driver_id
GROUP BY d.id, d.given_name, d.family_name
ORDER BY total_points DESC, driver_name;

-- ----------------------------------------------------------------------------
-- Equipes com seu número de pilotos distintos (parte inicial do Relatório 3).
-- LEFT JOIN garante que equipes sem resultados também apareçam (com 0).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_teams_driver_count AS
SELECT co.id,
       co.name AS team_name,
       COUNT(DISTINCT r.driver_id) AS driver_count
FROM constructors co
LEFT JOIN results r ON r.constructor_id = co.id
GROUP BY co.id, co.name
ORDER BY co.name;
