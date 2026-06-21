-- ============================================================================
-- 05_indexes.sql — Índices de apoio aos dashboards e relatórios
-- SCC-241 Final Project
--
-- CONCEITO: Índices.
-- Cada índice abaixo é justificado pelo filtro/junção/ordenação que otimiza,
-- conforme exigido pelo enunciado.
-- ============================================================================

-- RESULTS.constructor_id: filtro principal de tudo que é "escopo da equipe"
-- (dashboard da equipe, Relatórios 4 e 5: WHERE r.constructor_id = $1).
-- Sem ele, cada consulta da equipe faria varredura completa em RESULTS.
CREATE INDEX IF NOT EXISTS idx_results_constructor
    ON results (constructor_id);

-- RESULTS.driver_id: filtro principal de tudo que é "escopo do piloto"
-- (dashboard do piloto, Relatórios 6 e 7: WHERE r.driver_id = $1).
CREATE INDEX IF NOT EXISTS idx_results_driver
    ON results (driver_id);

-- RESULTS.status_id: índice de COBERTURA para o Relatório 1
-- (vw_results_by_status), que agrupa TODOS os results por status. Contendo
-- apenas status_id, permite um Index-Only Scan que evita varrer a tabela
-- inteira (ganho que cresce com o tamanho de RESULTS).
CREATE INDEX IF NOT EXISTS idx_results_status
    ON results (status_id);

-- Índice GiST sobre a posição geográfica dos aeroportos: exigido pelo
-- Relatório 2. O operador earth_box(...) @> ll_to_earth(...) só usa índice
-- se houver um GiST sobre ll_to_earth(latitude, longitude) — é ele que
-- restringe a busca aos aeroportos dentro da caixa de 100 km antes do
-- cálculo exato de distância.
CREATE INDEX IF NOT EXISTS idx_airports_earth
    ON airports USING gist (ll_to_earth(latitude_deg, longitude_deg));

-- CITIES (country_id, lower(name)): o Relatório 2 procura cidades
-- brasileiras pelo nome sem diferenciar maiúsculas
-- (WHERE pc.code='BR' AND LOWER(ci.name) = LOWER($1)).
CREATE INDEX IF NOT EXISTS idx_cities_country_lower_name
    ON cities (country_id, LOWER(name));

-- DRIVERS.family_name (case-insensitive): consulta da equipe
-- "buscar piloto por sobrenome" (WHERE LOWER(family_name) = LOWER($1)).
CREATE INDEX IF NOT EXISTS idx_drivers_family_name_lower
    ON drivers (LOWER(family_name));

-- RACES.season_id: NÃO criamos índice próprio. O filtro/junção por season_id
-- já é atendido pela restrição existente uq_races_season_round
-- UNIQUE (season_id, round), cujo índice B-tree tem season_id como coluna
-- LÍDER. Um índice separado seria redundante (apenas custo de escrita), então
-- garantimos sua remoção para manter o conjunto de índices enxuto e justificável.

-- RESULTS (race_id) já é coberto pelo UNIQUE (race_id, driver_id), que serve
-- como índice para o JOIN results → races dos dashboards e do Relatório 3.
