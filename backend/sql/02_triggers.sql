-- ============================================================================
-- 02_triggers.sql — Sincronização automática DRIVERS/CONSTRUCTORS → USERS
-- SCC-241 Final Project
--
-- CONCEITO: Triggers.
-- O enunciado exige que, sempre que um piloto ou equipe for criado ou
-- alterado, o registro correspondente em USERS seja criado/atualizado
-- automaticamente. Se o login gerado já existir, a operação deve ser
-- CANCELADA (RAISE EXCEPTION aborta a transação inteira, impedindo a
-- inserção inconsistente na tabela de origem).
--
-- A unicidade do login é GARANTIDA pela restrição UNIQUE(login) da tabela
-- USERS. Por isso, em vez de "verificar-e-depois-inserir" (SELECT seguido de
-- INSERT, sujeito a condição de corrida), tentamos a escrita e capturamos a
-- exceção unique_violation, traduzindo-a em uma mensagem de erro clara. A
-- restrição é checada no momento do INSERT/UPDATE (não é DEFERRABLE), de modo
-- que o cancelamento é imediato e seguro mesmo sob concorrência.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DRIVERS → USERS (INSERT)
-- AFTER INSERT: se o login <driver_ref>_d já existe, a unique_violation é
-- capturada e relançada como erro de negócio, desfazendo também o INSERT em
-- DRIVERS (mesma transação).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_user_after_driver_insert()
RETURNS trigger AS $$
BEGIN
    INSERT INTO users (login, password, type, original_id)
    VALUES (NEW.driver_ref || '_d',
            crypt(NEW.driver_ref, gen_salt('bf')),  -- senha = driver_ref, em hash
            'Driver',
            NEW.id);
    RETURN NEW;
EXCEPTION WHEN unique_violation THEN
    -- Login duplicado: cancela a inserção do piloto com mensagem clara.
    RAISE EXCEPTION 'Já existe um usuário com o login %; inserção do piloto cancelada.',
        NEW.driver_ref || '_d';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_insert_driver ON drivers;
CREATE TRIGGER trg_after_insert_driver
    AFTER INSERT ON drivers
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_user_after_driver_insert();

-- ----------------------------------------------------------------------------
-- DRIVERS → USERS (UPDATE)
-- Login e senha em USERS derivam EXCLUSIVAMENTE de driver_ref; logo, só há o
-- que sincronizar quando driver_ref muda. Essa guarda fica na cláusula WHEN do
-- trigger (abaixo), evitando até invocar a função em updates irrelevantes.
-- Atualizar o login da própria linha para o mesmo valor não conflita; um
-- choque real com OUTRO usuário dispara unique_violation, traduzida em
-- mensagem clara.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_user_after_driver_update()
RETURNS trigger AS $$
BEGIN
    UPDATE users
    SET login    = NEW.driver_ref || '_d',
        password = crypt(NEW.driver_ref, gen_salt('bf'))
    WHERE type = 'Driver' AND original_id = NEW.id;
    RETURN NEW;
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Já existe um usuário com o login %; alteração do piloto cancelada.',
        NEW.driver_ref || '_d';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_update_driver ON drivers;
CREATE TRIGGER trg_after_update_driver
    AFTER UPDATE ON drivers
    FOR EACH ROW
    WHEN (NEW.driver_ref IS DISTINCT FROM OLD.driver_ref)  -- só sincroniza se o ref mudou
    EXECUTE FUNCTION fn_sync_user_after_driver_update();

-- ----------------------------------------------------------------------------
-- CONSTRUCTORS → USERS (INSERT)
-- Mesmo padrão da inserção de pilotos: a UNIQUE(login) garante a unicidade e a
-- unique_violation é traduzida em mensagem de negócio, cancelando o INSERT em
-- CONSTRUCTORS (mesma transação).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_user_after_constructor_insert()
RETURNS trigger AS $$
BEGIN
    INSERT INTO users (login, password, type, original_id)
    VALUES (NEW.constructor_ref || '_c',
            crypt(NEW.constructor_ref, gen_salt('bf')),
            'Team',
            NEW.id);
    RETURN NEW;
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Já existe um usuário com o login %; inserção da equipe cancelada.',
        NEW.constructor_ref || '_c';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_insert_constructor ON constructors;
CREATE TRIGGER trg_after_insert_constructor
    AFTER INSERT ON constructors
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_user_after_constructor_insert();

-- ----------------------------------------------------------------------------
-- CONSTRUCTORS → USERS (UPDATE)
-- Login e senha em USERS derivam exclusivamente de constructor_ref; a guarda
-- "ref mudou" fica na cláusula WHEN do trigger. Conflito real com outro
-- usuário dispara unique_violation, traduzida em mensagem clara.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_sync_user_after_constructor_update()
RETURNS trigger AS $$
BEGIN
    UPDATE users
    SET login    = NEW.constructor_ref || '_c',
        password = crypt(NEW.constructor_ref, gen_salt('bf'))
    WHERE type = 'Team' AND original_id = NEW.id;
    RETURN NEW;
EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Já existe um usuário com o login %; alteração da equipe cancelada.',
        NEW.constructor_ref || '_c';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_after_update_constructor ON constructors;
CREATE TRIGGER trg_after_update_constructor
    AFTER UPDATE ON constructors
    FOR EACH ROW
    WHEN (NEW.constructor_ref IS DISTINCT FROM OLD.constructor_ref)  -- só sincroniza se o ref mudou
    EXECUTE FUNCTION fn_sync_user_after_constructor_update();
