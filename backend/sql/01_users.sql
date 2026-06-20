-- ============================================================================
-- 01_users.sql — Tabelas USERS e USERS_LOG + carga inicial
-- SCC-241 Final Project
--
-- CONCEITO: Controle de acesso e autenticação.
-- A autenticação é feita via tabela USERS (não via roles do PostgreSQL).
-- Por isso, as senhas NÃO podem ficar em texto plano: usamos a extensão
-- pgcrypto com crypt() + gen_salt('bf') (bcrypt, com salt aleatório),
-- de forma que o hash armazenado não é reversível.
-- ============================================================================

-- pgcrypto fornece crypt() e gen_salt() para hashing seguro de senhas.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- Tabela USERS
-- userid      : identificador interno do usuário
-- login       : único (exigência do enunciado)
-- password    : hash bcrypt — nunca texto plano
-- type        : restrito por CHECK a 'Admin' | 'Team' | 'Driver'
-- original_id : id na tabela de origem (DRIVERS.id ou CONSTRUCTORS.id);
--               NULL para o administrador
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    userid      SERIAL PRIMARY KEY,
    login       VARCHAR(255) NOT NULL UNIQUE,
    password    TEXT         NOT NULL,
    type        VARCHAR(10)  NOT NULL CHECK (type IN ('Admin', 'Team', 'Driver')),
    original_id INTEGER
);

-- ----------------------------------------------------------------------------
-- Tabela USERS_LOG — auditoria de acessos (LOGIN / LOGOUT)
-- Preenchida pela aplicação nos endpoints de login e logout.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users_log (
    log_id    SERIAL PRIMARY KEY,
    userid    INTEGER NOT NULL REFERENCES users(userid),
    action    VARCHAR(10) NOT NULL CHECK (action IN ('LOGIN', 'LOGOUT')),
    action_at TIMESTAMP NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- Carga inicial
-- Admin: login 'admin', senha 'admin' (armazenada como hash bcrypt).
-- ON CONFLICT torna o script idempotente (pode ser reexecutado sem erro).
-- ----------------------------------------------------------------------------
INSERT INTO users (login, password, type, original_id)
VALUES ('admin', crypt('admin', gen_salt('bf')), 'Admin', NULL)
ON CONFLICT (login) DO NOTHING;

-- Um usuário por equipe já cadastrada: <constructor_ref>_c / senha <constructor_ref>
INSERT INTO users (login, password, type, original_id)
SELECT c.constructor_ref || '_c',
       crypt(c.constructor_ref, gen_salt('bf')),
       'Team',
       c.id
FROM constructors c
ON CONFLICT (login) DO NOTHING;

-- Um usuário por piloto já cadastrado: <driver_ref>_d / senha <driver_ref>
INSERT INTO users (login, password, type, original_id)
SELECT d.driver_ref || '_d',
       crypt(d.driver_ref, gen_salt('bf')),
       'Driver',
       d.id
FROM drivers d
ON CONFLICT (login) DO NOTHING;
