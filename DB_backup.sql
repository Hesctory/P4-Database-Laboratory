--
-- PostgreSQL database dump
--

\restrict xWCjdH4sZ7CXNVQkR1IhGav55cz5E8d9KkLhmAOJX2GzKz00qsmJ9oglG2TbNxW

-- Dumped from database version 18.3 (Ubuntu 18.3-1.pgdg22.04+1)
-- Dumped by pg_dump version 18.3 (Ubuntu 18.3-1.pgdg22.04+1)

-- Started on 2026-06-07 14:42:17 -03

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 291 (class 1255 OID 20711)
-- Name: auditaeroporto(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auditaeroporto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Para operação de INSERT
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO Airports_Audit (
            airport_id, ident, name, city_id, 
            operacao, data_hora, usuario_bd
        ) VALUES (
            NEW.id, NEW.ident, NEW.name, NEW.city_id,
            'I', NOW(), CURRENT_USER
        );
        RETURN NEW;
    
    -- Para operação de DELETE
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO Airports_Audit (
            airport_id, ident, name, city_id,
            operacao, data_hora, usuario_bd
        ) VALUES (
            OLD.id, OLD.ident, OLD.name, OLD.city_id,
            'D', NOW(), CURRENT_USER
        );
        RETURN OLD;
    
    -- Para operação de UPDATE
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO Airports_Audit (
            airport_id, ident, name, city_id,
            operacao, data_hora, usuario_bd
        ) VALUES (
            NEW.id, NEW.ident, NEW.name, NEW.city_id,
            'U', NOW(), CURRENT_USER
        );
        RETURN NEW;
    END IF;
END;
$$;


ALTER FUNCTION public.auditaeroporto() OWNER TO postgres;

--
-- TOC entry 287 (class 1255 OID 20662)
-- Name: cidade_chamada(text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.cidade_chamada(IN p_city_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_count INTEGER;
    v_city_name TEXT;
    v_population BIGINT;
    v_country_name TEXT;
    v_output TEXT;
    cur_cities CURSOR FOR
        SELECT c.name AS city_name, c.population, co.name AS country_name
        FROM cities c
        JOIN countries co ON co.id = c.country_id
        WHERE LOWER(c.name) = LOWER(p_city_name);
BEGIN
    -- First count how many cities match
    SELECT COUNT(*) INTO v_count
    FROM cities
    WHERE LOWER(name) = LOWER(p_city_name);
    
    v_output := 'Contagem: ' || v_count || ' |';
    RAISE NOTICE '%', v_output;
    
    -- Handle case when no cities found
    IF v_count = 0 THEN
        RAISE NOTICE 'No cities found with name: %', p_city_name;
        RETURN;
    END IF;
    
    -- Loop through each city found
    FOR record IN cur_cities
    LOOP
        RAISE NOTICE 'Nome: %, População: %, País: %', 
            record.city_name, 
            COALESCE(record.population, 0),
            record.country_name;
    END LOOP;
END;
$$;


ALTER PROCEDURE public.cidade_chamada(IN p_city_name text) OWNER TO postgres;

--
-- TOC entry 272 (class 1255 OID 20091)
-- Name: haversine_km(double precision, double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.haversine_km(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision) RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    a DOUBLE PRECISION;
BEGIN
    a := sin(radians(lat2 - lat1) / 2) ^ 2
       + cos(radians(lat1)) * cos(radians(lat2))
       * sin(radians(lon2 - lon1) / 2) ^ 2;
    RETURN 6371.0 * 2 * asin(sqrt(GREATEST(0.0, LEAST(1.0, a))));
END;
$$;


ALTER FUNCTION public.haversine_km(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision) OWNER TO postgres;

--
-- TOC entry 274 (class 1255 OID 21053)
-- Name: mede_tempo_simples(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.mede_tempo_simples(query text) RETURNS double precision
    LANGUAGE plpgsql
    AS $$
DECLARE
    t_inicio TIMESTAMP;
    t_fim TIMESTAMP;
    diff DOUBLE PRECISION;
    i INTEGER;
BEGIN
    t_inicio := clock_timestamp();
    FOR i IN 1..100 LOOP
        EXECUTE query;
    END LOOP;
    t_fim := clock_timestamp();
    diff := EXTRACT(EPOCH FROM (t_fim - t_inicio)) * 1000; -- milissegundos totais
    RETURN diff / 100.0; -- média por execução
END;
$$;


ALTER FUNCTION public.mede_tempo_simples(query text) OWNER TO postgres;

--
-- TOC entry 273 (class 1255 OID 20657)
-- Name: nome_nacionalidade(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.nome_nacionalidade(p_constructor_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_nationality TEXT;
BEGIN
    -- Get the nationality of the constructor
    SELECT nationality INTO v_nationality
    FROM constructors
    WHERE name = p_constructor_name;
    
    -- Handle case when constructor doesn't exist
    IF NOT FOUND THEN
        RETURN 'Constructor not found: ' || p_constructor_name;
    END IF;
    
    RETURN v_nationality;
END;
$$;


ALTER FUNCTION public.nome_nacionalidade(p_constructor_name text) OWNER TO postgres;

--
-- TOC entry 288 (class 1255 OID 20663)
-- Name: numero_vitorias(text, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.numero_vitorias(p_first_name text, p_last_name text, p_year integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_wins INTEGER;
    v_driver_id INTEGER;
BEGIN
    -- Get driver ID
    SELECT id INTO v_driver_id
    FROM drivers
    WHERE given_name = p_first_name AND family_name = p_last_name;
    
    -- Handle driver not found exception
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Driver not found: % %', p_first_name, p_last_name;
    END IF;
    
    -- Count victories (position_order = 1 means winner)
    IF p_year IS NULL THEN
        SELECT COUNT(*) INTO v_wins
        FROM results r
        JOIN races ra ON ra.id = r.race_id
        WHERE r.driver_id = v_driver_id AND r.position_order = 1;
    ELSE
        SELECT COUNT(*) INTO v_wins
        FROM results r
        JOIN races ra ON ra.id = r.race_id
        JOIN seasons s ON s.id = ra.season_id
        WHERE r.driver_id = v_driver_id 
          AND r.position_order = 1
          AND s.year = p_year;
    END IF;
    
    RETURN v_wins;
END;
$$;


ALTER FUNCTION public.numero_vitorias(p_first_name text, p_last_name text, p_year integer) OWNER TO postgres;

--
-- TOC entry 289 (class 1255 OID 20665)
-- Name: pais_continente(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pais_continente() RETURNS TABLE(country_name text, continent_name text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_countries CURSOR FOR
        SELECT c.name AS country_name, co.name AS continent_name
        FROM countries c
        JOIN continents co ON co.id = c.continent_id
        WHERE LENGTH(c.name) <= 15
        ORDER BY c.name;
    v_country_name TEXT;
    v_continent_name TEXT;
BEGIN
    OPEN cur_countries;
    
    LOOP
        FETCH cur_countries INTO v_country_name, v_continent_name;
        EXIT WHEN NOT FOUND;
        
        country_name := v_country_name;
        continent_name := v_continent_name;
        RETURN NEXT;
    END LOOP;
    
    CLOSE cur_countries;
    
    -- If no rows found, just return empty set
    RETURN;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Handle any exceptions
        RAISE NOTICE 'Error in Pais_Continente: %', SQLERRM;
        RETURN;
END;
$$;


ALTER FUNCTION public.pais_continente() OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 20661)
-- Name: pilotos_nacionalidade(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pilotos_nacionalidade(p_nationality text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_counter INTEGER := 0;
    cur_drivers CURSOR FOR
        SELECT given_name || ' ' || family_name AS full_name
        FROM drivers
        WHERE nationality = p_nationality
        ORDER BY family_name, given_name;
    v_driver_record RECORD;
BEGIN
    -- Exception handling for invalid parameter
    IF p_nationality IS NULL OR TRIM(p_nationality) = '' THEN
        RAISE EXCEPTION 'Nationality cannot be null or empty';
    END IF;
    
    -- Open cursor and loop through drivers
    OPEN cur_drivers;
    
    LOOP
        FETCH cur_drivers INTO v_driver_record;
        EXIT WHEN NOT FOUND;
        
        v_counter := v_counter + 1;
        RAISE NOTICE '% Nome: %', v_counter, v_driver_record.full_name;
    END LOOP;
    
    CLOSE cur_drivers;
    
    -- Handle case when no drivers found
    IF v_counter = 0 THEN
        RAISE NOTICE 'No drivers found with nationality: %', p_nationality;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- In PostgreSQL, cursors are automatically closed at transaction end
        -- Just re-raise the exception with a notice
        RAISE NOTICE 'Error in Pilotos_Nacionalidade: %', SQLERRM;
        RAISE;
END;
$$;


ALTER FUNCTION public.pilotos_nacionalidade(p_nationality text) OWNER TO postgres;

--
-- TOC entry 290 (class 1255 OID 20666)
-- Name: valida_volta(text, text, integer, text, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.valida_volta(p_track_name text, p_country_name text, p_year integer, p_driver_given_name text, p_driver_family_name text, p_lap_number integer, OUT p_driver_id integer, OUT p_race_id integer, OUT p_status integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_circuit_id INTEGER;
    v_max_lap INTEGER;
BEGIN
    -- Initialize outputs
    p_driver_id := NULL;
    p_race_id := NULL;
    
    -- Check if driver exists (Status 3)
    SELECT id INTO p_driver_id
    FROM drivers
    WHERE given_name = p_driver_given_name AND family_name = p_driver_family_name;
    
    IF NOT FOUND THEN
        p_status := 3;
        RETURN;
    END IF;
    
    -- Check if circuit exists in given country (Status 4)
    SELECT c.id INTO v_circuit_id
    FROM circuits c
    LEFT JOIN cities ci ON ci.id = c.city_id
    LEFT JOIN countries co ON co.id = ci.country_id
    WHERE c.name = p_track_name AND co.name = p_country_name;
    
    IF NOT FOUND THEN
        p_status := 4;
        RETURN;
    END IF;
    
    -- Check if race exists at this circuit in given year (Status 5)
    SELECT r.id INTO p_race_id
    FROM races r
    JOIN seasons s ON s.id = r.season_id
    WHERE r.circuit_id = v_circuit_id AND s.year = p_year;
    
    IF NOT FOUND THEN
        p_status := 5;
        RETURN;
    END IF;
    
    -- Now driver and race exist
    -- Get the last lap this driver completed in this race
    SELECT MAX(laps) INTO v_max_lap
    FROM results
    WHERE driver_id = p_driver_id AND race_id = p_race_id;
    
    -- Check driver's lap history in this race
    IF v_max_lap IS NULL THEN
        -- Driver has no laps in this race (Status 2)
        IF p_lap_number = 1 THEN
            p_status := 0;  -- Can be inserted as lap 1
        ELSE
            p_status := 2;  -- Must be lap 1
        END IF;
        RETURN;
    END IF;
    
    -- Check if this lap already exists (Status 1)
    IF p_lap_number <= v_max_lap THEN
        p_status := 1;
        RETURN;
    END IF;
    
    -- Check if this is the next lap (Status 0) or missing previous lap (Status 6)
    IF p_lap_number = v_max_lap + 1 THEN
        p_status := 0;
    ELSE
        p_status := 6;
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        p_driver_id := NULL;
        p_race_id := NULL;
        p_status := 6;
END;
$$;


ALTER FUNCTION public.valida_volta(p_track_name text, p_country_name text, p_year integer, p_driver_given_name text, p_driver_family_name text, p_lap_number integer, OUT p_driver_id integer, OUT p_race_id integer, OUT p_status integer) OWNER TO postgres;

--
-- TOC entry 292 (class 1255 OID 20713)
-- Name: verificaqualifying(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verificaqualifying() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    posicao_existente INTEGER;
BEGIN
    -- REGRA (a): Verificar se position é maior que zero
    IF NEW.position <= 0 THEN
        RAISE EXCEPTION 'Posição inválida! Operação cancelada.';
    END IF;
    
    -- REGRA (b): Verificar se já existe um piloto com a mesma position nesta corrida
    -- Para UPDATE, precisamos excluir o próprio registro da verificação
    IF (TG_OP = 'INSERT') THEN
        SELECT COUNT(*) INTO posicao_existente
        FROM qualifying
        WHERE race_id = NEW.race_id 
          AND position = NEW.position;
        
        IF posicao_existente > 0 THEN
            RAISE EXCEPTION 'Posição já cadastrada para essa corrida! Operação cancelada.';
        END IF;
        
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Se a position não mudou, não precisamos verificar
        IF NEW.position != OLD.position THEN
            SELECT COUNT(*) INTO posicao_existente
            FROM qualifying
            WHERE race_id = NEW.race_id 
              AND position = NEW.position
              AND id != NEW.id;  -- Exclui o próprio registro
            
            IF posicao_existente > 0 THEN
                RAISE EXCEPTION 'Posição já cadastrada para essa corrida! Operação cancelada.';
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verificaqualifying() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 243 (class 1259 OID 19460)
-- Name: airports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.airports (
    id integer NOT NULL,
    ident character varying(100) NOT NULL,
    airport_type_id integer NOT NULL,
    name text NOT NULL,
    latitude_deg double precision,
    longitude_deg double precision,
    elevation_ft integer,
    city_id integer,
    scheduled_service character varying(10),
    icao_code character varying(10),
    iata_code character varying(10),
    gps_code character varying(20),
    local_code character varying(20),
    home_link text,
    wikipedia_link text,
    keywords text
);


ALTER TABLE public.airports OWNER TO postgres;

--
-- TOC entry 3722 (class 0 OID 0)
-- Dependencies: 243
-- Name: TABLE airports; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.airports IS 'Aeroportos mundiais';


--
-- TOC entry 3723 (class 0 OID 0)
-- Dependencies: 243
-- Name: COLUMN airports.ident; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.airports.ident IS 'Identificador único do aeroporto (geralmente ICAO ou IATA)';


--
-- TOC entry 3724 (class 0 OID 0)
-- Dependencies: 243
-- Name: COLUMN airports.elevation_ft; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.airports.elevation_ft IS 'Elevação do aeroporto em pés acima do nível do mar';


--
-- TOC entry 3725 (class 0 OID 0)
-- Dependencies: 243
-- Name: COLUMN airports.icao_code; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.airports.icao_code IS 'Código ICAO de 4 letras';


--
-- TOC entry 3726 (class 0 OID 0)
-- Dependencies: 243
-- Name: COLUMN airports.iata_code; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.airports.iata_code IS 'Código IATA de 3 letras';


--
-- TOC entry 239 (class 1259 OID 19422)
-- Name: cities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cities (
    id integer NOT NULL,
    name character varying(200) NOT NULL,
    ascii_name character varying(200),
    alternate_names text,
    latitude double precision,
    longitude double precision,
    feature_code_id integer,
    country_id integer NOT NULL,
    time_zone_id integer,
    cc2 character varying(200),
    admin1_code character varying(20),
    admin2_code character varying(80),
    admin3_code character varying(20),
    admin4_code character varying(20),
    population bigint,
    elevation integer,
    dem integer,
    modification_date date
);


ALTER TABLE public.cities OWNER TO postgres;

--
-- TOC entry 3727 (class 0 OID 0)
-- Dependencies: 239
-- Name: TABLE cities; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.cities IS 'Cidades e localidades geográficas';


--
-- TOC entry 3728 (class 0 OID 0)
-- Dependencies: 239
-- Name: COLUMN cities.ascii_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cities.ascii_name IS 'Nome da cidade sem caracteres especiais/accentuação';


--
-- TOC entry 3729 (class 0 OID 0)
-- Dependencies: 239
-- Name: COLUMN cities.alternate_names; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cities.alternate_names IS 'Nomes alternativos separados por vírgula';


--
-- TOC entry 3730 (class 0 OID 0)
-- Dependencies: 239
-- Name: COLUMN cities.dem; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.cities.dem IS 'Modelo Digital de Elevação (DEM) em metros';


--
-- TOC entry 226 (class 1259 OID 19312)
-- Name: continents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.continents (
    id integer NOT NULL,
    code character varying(2) NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.continents OWNER TO postgres;

--
-- TOC entry 3731 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE continents; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.continents IS 'Continentes do mundo';


--
-- TOC entry 3732 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN continents.code; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.continents.code IS 'Código de 2 letras do continente';


--
-- TOC entry 3733 (class 0 OID 0)
-- Dependencies: 226
-- Name: COLUMN continents.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.continents.name IS 'Nome completo do continente';


--
-- TOC entry 228 (class 1259 OID 19326)
-- Name: countries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.countries (
    id integer NOT NULL,
    code character varying(2) NOT NULL,
    name character varying(255) NOT NULL,
    wikipedia_link text,
    keywords text,
    continent_id integer NOT NULL,
    nationality character varying(100)
);


ALTER TABLE public.countries OWNER TO postgres;

--
-- TOC entry 3734 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE countries; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.countries IS 'Países do mundo';


--
-- TOC entry 3735 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN countries.code; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.countries.code IS 'Código ISO 3166-1 alpha-2 do país';


--
-- TOC entry 3736 (class 0 OID 0)
-- Dependencies: 228
-- Name: COLUMN countries.keywords; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.countries.keywords IS 'Termos alternativos para busca e matching';


--
-- TOC entry 266 (class 1259 OID 20767)
-- Name: aeroportos_brasileiros; Type: MATERIALIZED VIEW; Schema: public; Owner: postgres
--

CREATE MATERIALIZED VIEW public.aeroportos_brasileiros AS
 SELECT a.id AS airport_id,
    a.name AS airport_name,
    a.latitude_deg,
    a.longitude_deg,
    c.name AS city_name,
    c.population AS city_population,
    co.name AS country_name,
    cont.name AS continent_name
   FROM (((public.airports a
     JOIN public.cities c ON ((a.city_id = c.id)))
     JOIN public.countries co ON ((c.country_id = co.id)))
     JOIN public.continents cont ON ((co.continent_id = cont.id)))
  WHERE ((co.name)::text = 'Brazil'::text)
  WITH NO DATA;


ALTER MATERIALIZED VIEW public.aeroportos_brasileiros OWNER TO postgres;

--
-- TOC entry 267 (class 1259 OID 20788)
-- Name: aeroportos_sem_cidades; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.aeroportos_sem_cidades AS
 SELECT id,
    ident,
    airport_type_id,
    name,
    latitude_deg,
    longitude_deg,
    elevation_ft,
    city_id,
    scheduled_service,
    icao_code,
    iata_code,
    gps_code,
    local_code,
    home_link,
    wikipedia_link,
    keywords
   FROM public.airports
  WHERE (city_id IS NULL);


ALTER VIEW public.aeroportos_sem_cidades OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 19449)
-- Name: airport_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.airport_types (
    id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.airport_types OWNER TO postgres;

--
-- TOC entry 3737 (class 0 OID 0)
-- Dependencies: 241
-- Name: TABLE airport_types; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.airport_types IS 'Tipos de aeroporto (classificação por tamanho/tráfego)';


--
-- TOC entry 240 (class 1259 OID 19448)
-- Name: airport_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.airport_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.airport_types_id_seq OWNER TO postgres;

--
-- TOC entry 3738 (class 0 OID 0)
-- Dependencies: 240
-- Name: airport_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.airport_types_id_seq OWNED BY public.airport_types.id;


--
-- TOC entry 265 (class 1259 OID 20699)
-- Name: airports_audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.airports_audit (
    audit_id integer NOT NULL,
    airport_id integer,
    ident character varying(100),
    name text,
    city_id integer,
    operacao character(1) NOT NULL,
    data_hora timestamp without time zone NOT NULL,
    usuario_bd text NOT NULL
);


ALTER TABLE public.airports_audit OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 20698)
-- Name: airports_audit_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.airports_audit_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.airports_audit_audit_id_seq OWNER TO postgres;

--
-- TOC entry 3739 (class 0 OID 0)
-- Dependencies: 264
-- Name: airports_audit_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.airports_audit_audit_id_seq OWNED BY public.airports_audit.audit_id;


--
-- TOC entry 242 (class 1259 OID 19459)
-- Name: airports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.airports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.airports_id_seq OWNER TO postgres;

--
-- TOC entry 3740 (class 0 OID 0)
-- Dependencies: 242
-- Name: airports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.airports_id_seq OWNED BY public.airports.id;


--
-- TOC entry 268 (class 1259 OID 20792)
-- Name: cidades_brasileiras; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.cidades_brasileiras AS
 SELECT c.id,
    c.name,
    c.latitude,
    c.longitude,
    c.population
   FROM (public.cities c
     JOIN public.countries co ON ((c.country_id = co.id)))
  WHERE (((co.name)::text = 'Brazil'::text) AND (c.population >= 100000));


ALTER VIEW public.cidades_brasileiras OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 19509)
-- Name: circuits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.circuits (
    id integer NOT NULL,
    circuit_ref character varying(255) NOT NULL,
    name text NOT NULL,
    lat double precision,
    long double precision,
    city_id integer,
    wikipedia_url text
);


ALTER TABLE public.circuits OWNER TO postgres;

--
-- TOC entry 3741 (class 0 OID 0)
-- Dependencies: 249
-- Name: TABLE circuits; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.circuits IS 'Autódromos da Fórmula 1';


--
-- TOC entry 3742 (class 0 OID 0)
-- Dependencies: 249
-- Name: COLUMN circuits.circuit_ref; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.circuits.circuit_ref IS 'Identificador único vindo de circuits.csv';


--
-- TOC entry 3743 (class 0 OID 0)
-- Dependencies: 249
-- Name: COLUMN circuits.lat; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.circuits.lat IS 'Latitude do circuito em graus decimais';


--
-- TOC entry 3744 (class 0 OID 0)
-- Dependencies: 249
-- Name: COLUMN circuits.long; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.circuits.long IS 'Longitude do circuito em graus decimais';


--
-- TOC entry 269 (class 1259 OID 20797)
-- Name: circuits_completa; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.circuits_completa AS
 SELECT c.name AS circuit_name,
    c.lat,
    c.long,
    ci.name AS city_name,
    co.name AS country_name,
    co.code AS country_code,
    cont.name AS continent_name
   FROM (((public.circuits c
     LEFT JOIN public.cities ci ON ((c.city_id = ci.id)))
     LEFT JOIN public.countries co ON ((ci.country_id = co.id)))
     LEFT JOIN public.continents cont ON ((co.continent_id = cont.id)));


ALTER VIEW public.circuits_completa OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 19508)
-- Name: circuits_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.circuits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.circuits_id_seq OWNER TO postgres;

--
-- TOC entry 3745 (class 0 OID 0)
-- Dependencies: 248
-- Name: circuits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.circuits_id_seq OWNED BY public.circuits.id;


--
-- TOC entry 238 (class 1259 OID 19421)
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cities_id_seq OWNER TO postgres;

--
-- TOC entry 3746 (class 0 OID 0)
-- Dependencies: 238
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- TOC entry 263 (class 1259 OID 19683)
-- Name: constructor_standings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.constructor_standings (
    standing_id integer NOT NULL,
    constructor_id integer NOT NULL
);


ALTER TABLE public.constructor_standings OWNER TO postgres;

--
-- TOC entry 3747 (class 0 OID 0)
-- Dependencies: 263
-- Name: TABLE constructor_standings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.constructor_standings IS 'Especialização da classificação para construtores';


--
-- TOC entry 3748 (class 0 OID 0)
-- Dependencies: 263
-- Name: COLUMN constructor_standings.standing_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.constructor_standings.standing_id IS 'Referência aos dados de classificação';


--
-- TOC entry 3749 (class 0 OID 0)
-- Dependencies: 263
-- Name: COLUMN constructor_standings.constructor_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.constructor_standings.constructor_id IS 'Construtor nesta posição da classificação';


--
-- TOC entry 251 (class 1259 OID 19528)
-- Name: constructors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.constructors (
    id integer NOT NULL,
    constructor_ref character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    nationality character varying(255) NOT NULL,
    wikipedia_url text,
    country_id integer
);


ALTER TABLE public.constructors OWNER TO postgres;

--
-- TOC entry 3750 (class 0 OID 0)
-- Dependencies: 251
-- Name: TABLE constructors; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.constructors IS 'Escuderias da Fórmula 1';


--
-- TOC entry 3751 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN constructors.constructor_ref; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.constructors.constructor_ref IS 'Identificador único vindo de constructors.csv';


--
-- TOC entry 3752 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN constructors.name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.constructors.name IS 'Nome oficial da escuderia';


--
-- TOC entry 3753 (class 0 OID 0)
-- Dependencies: 251
-- Name: COLUMN constructors.nationality; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.constructors.nationality IS 'Gentílico principal da escuderia';


--
-- TOC entry 250 (class 1259 OID 19527)
-- Name: constructors_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.constructors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.constructors_id_seq OWNER TO postgres;

--
-- TOC entry 3754 (class 0 OID 0)
-- Dependencies: 250
-- Name: constructors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.constructors_id_seq OWNED BY public.constructors.id;


--
-- TOC entry 225 (class 1259 OID 19311)
-- Name: continents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.continents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.continents_id_seq OWNER TO postgres;

--
-- TOC entry 3755 (class 0 OID 0)
-- Dependencies: 225
-- Name: continents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.continents_id_seq OWNED BY public.continents.id;


--
-- TOC entry 271 (class 1259 OID 20807)
-- Name: correcao_aeroportos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.correcao_aeroportos AS
 SELECT DISTINCT id,
    name,
    latitude_deg,
    longitude_deg,
    city_id
   FROM public.aeroportos_sem_cidades a
  WHERE (EXISTS ( SELECT 1
           FROM public.cidades_brasileiras cb
          WHERE (public.haversine_km(a.latitude_deg, a.longitude_deg, cb.latitude, cb.longitude) <= (10)::double precision)));


ALTER VIEW public.correcao_aeroportos OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 19325)
-- Name: countries_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.countries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.countries_id_seq OWNER TO postgres;

--
-- TOC entry 3756 (class 0 OID 0)
-- Dependencies: 227
-- Name: countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.countries_id_seq OWNED BY public.countries.id;


--
-- TOC entry 235 (class 1259 OID 19389)
-- Name: country_languages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.country_languages (
    country_id integer NOT NULL,
    language_id integer NOT NULL
);


ALTER TABLE public.country_languages OWNER TO postgres;

--
-- TOC entry 3757 (class 0 OID 0)
-- Dependencies: 235
-- Name: TABLE country_languages; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.country_languages IS 'Relacionamento muitos-para-muitos entre países e idiomas';


--
-- TOC entry 262 (class 1259 OID 19666)
-- Name: driver_standings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.driver_standings (
    standing_id integer NOT NULL,
    driver_id integer NOT NULL
);


ALTER TABLE public.driver_standings OWNER TO postgres;

--
-- TOC entry 3758 (class 0 OID 0)
-- Dependencies: 262
-- Name: TABLE driver_standings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.driver_standings IS 'Especialização da classificação para pilotos';


--
-- TOC entry 3759 (class 0 OID 0)
-- Dependencies: 262
-- Name: COLUMN driver_standings.standing_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.driver_standings.standing_id IS 'Referência aos dados de classificação';


--
-- TOC entry 3760 (class 0 OID 0)
-- Dependencies: 262
-- Name: COLUMN driver_standings.driver_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.driver_standings.driver_id IS 'Piloto nesta posição da classificação';


--
-- TOC entry 253 (class 1259 OID 19545)
-- Name: drivers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.drivers (
    id integer NOT NULL,
    driver_ref character varying(255) NOT NULL,
    given_name character varying(255) NOT NULL,
    family_name character varying(255) NOT NULL,
    nationality character varying(255) NOT NULL,
    date_of_birth date,
    country_id integer
);


ALTER TABLE public.drivers OWNER TO postgres;

--
-- TOC entry 3761 (class 0 OID 0)
-- Dependencies: 253
-- Name: TABLE drivers; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.drivers IS 'Pilotos da Fórmula 1';


--
-- TOC entry 3762 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN drivers.driver_ref; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.drivers.driver_ref IS 'Identificador único vindo de drivers.csv';


--
-- TOC entry 3763 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN drivers.given_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.drivers.given_name IS 'Primeiro nome do piloto';


--
-- TOC entry 3764 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN drivers.family_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.drivers.family_name IS 'Sobrenome do piloto';


--
-- TOC entry 3765 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN drivers.nationality; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.drivers.nationality IS 'Gentílico principal do piloto';


--
-- TOC entry 3766 (class 0 OID 0)
-- Dependencies: 253
-- Name: COLUMN drivers.date_of_birth; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.drivers.date_of_birth IS 'Data de nascimento do piloto';


--
-- TOC entry 252 (class 1259 OID 19544)
-- Name: drivers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.drivers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.drivers_id_seq OWNER TO postgres;

--
-- TOC entry 3767 (class 0 OID 0)
-- Dependencies: 252
-- Name: drivers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.drivers_id_seq OWNED BY public.drivers.id;


--
-- TOC entry 237 (class 1259 OID 19407)
-- Name: feature_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.feature_codes (
    id integer NOT NULL,
    feature_class character(1) NOT NULL,
    feature_code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    description text
);


ALTER TABLE public.feature_codes OWNER TO postgres;

--
-- TOC entry 3768 (class 0 OID 0)
-- Dependencies: 237
-- Name: TABLE feature_codes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.feature_codes IS 'Códigos de características geográficas do GeoNames';


--
-- TOC entry 3769 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN feature_codes.feature_class; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.feature_codes.feature_class IS 'Classe da característica (A=Admin, H=Hydro, P=Populated Place, etc.)';


--
-- TOC entry 3770 (class 0 OID 0)
-- Dependencies: 237
-- Name: COLUMN feature_codes.feature_code; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.feature_codes.feature_code IS 'Código específico dentro da classe';


--
-- TOC entry 236 (class 1259 OID 19406)
-- Name: feature_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.feature_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.feature_codes_id_seq OWNER TO postgres;

--
-- TOC entry 3771 (class 0 OID 0)
-- Dependencies: 236
-- Name: feature_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.feature_codes_id_seq OWNED BY public.feature_codes.id;


--
-- TOC entry 234 (class 1259 OID 19370)
-- Name: iso_language_codes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.iso_language_codes (
    id integer NOT NULL,
    iso_639_3 character varying(10),
    iso_639_2 character varying(10),
    iso_639_1 character varying(10),
    language_id integer NOT NULL
);


ALTER TABLE public.iso_language_codes OWNER TO postgres;

--
-- TOC entry 3772 (class 0 OID 0)
-- Dependencies: 234
-- Name: TABLE iso_language_codes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.iso_language_codes IS 'Códigos ISO 639 para idiomas';


--
-- TOC entry 3773 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN iso_language_codes.iso_639_3; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.iso_language_codes.iso_639_3 IS 'Código de 3 letras (mais específico)';


--
-- TOC entry 3774 (class 0 OID 0)
-- Dependencies: 234
-- Name: COLUMN iso_language_codes.iso_639_1; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.iso_language_codes.iso_639_1 IS 'Código de 2 letras (mais usado)';


--
-- TOC entry 233 (class 1259 OID 19369)
-- Name: iso_language_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.iso_language_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.iso_language_codes_id_seq OWNER TO postgres;

--
-- TOC entry 3775 (class 0 OID 0)
-- Dependencies: 233
-- Name: iso_language_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.iso_language_codes_id_seq OWNED BY public.iso_language_codes.id;


--
-- TOC entry 232 (class 1259 OID 19359)
-- Name: language_names; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.language_names (
    id integer NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.language_names OWNER TO postgres;

--
-- TOC entry 3776 (class 0 OID 0)
-- Dependencies: 232
-- Name: TABLE language_names; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.language_names IS 'Nomes padronizados dos idiomas';


--
-- TOC entry 231 (class 1259 OID 19358)
-- Name: language_names_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.language_names_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.language_names_id_seq OWNER TO postgres;

--
-- TOC entry 3777 (class 0 OID 0)
-- Dependencies: 231
-- Name: language_names_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.language_names_id_seq OWNED BY public.language_names.id;


--
-- TOC entry 270 (class 1259 OID 20802)
-- Name: problemas_aeroportos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.problemas_aeroportos AS
 SELECT a.id,
    a.name AS airport_name,
    a.latitude_deg,
    a.longitude_deg,
    cb.name AS cidade_candidata,
    cb.population AS populacao_candidata,
    public.haversine_km(a.latitude_deg, a.longitude_deg, cb.latitude, cb.longitude) AS distancia_km
   FROM (public.aeroportos_sem_cidades a
     CROSS JOIN public.cidades_brasileiras cb)
  WHERE (public.haversine_km(a.latitude_deg, a.longitude_deg, cb.latitude, cb.longitude) <= (10)::double precision);


ALTER VIEW public.problemas_aeroportos OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 19590)
-- Name: qualifying; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.qualifying (
    id integer NOT NULL,
    race_id integer NOT NULL,
    driver_id integer NOT NULL,
    constructor_id integer NOT NULL,
    "position" integer,
    q1 character varying(16),
    q2 character varying(16),
    q3 character varying(16)
);


ALTER TABLE public.qualifying OWNER TO postgres;

--
-- TOC entry 3778 (class 0 OID 0)
-- Dependencies: 257
-- Name: TABLE qualifying; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.qualifying IS 'Resultados das sessões de qualificação';


--
-- TOC entry 3779 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN qualifying.q1; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.qualifying.q1 IS 'Melhor tempo na fase Q1 (MM:SS.sss)';


--
-- TOC entry 3780 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN qualifying.q2; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.qualifying.q2 IS 'Melhor tempo na fase Q2 (MM:SS.sss)';


--
-- TOC entry 3781 (class 0 OID 0)
-- Dependencies: 257
-- Name: COLUMN qualifying.q3; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.qualifying.q3 IS 'Melhor tempo na fase Q3 (MM:SS.sss)';


--
-- TOC entry 256 (class 1259 OID 19589)
-- Name: qualifying_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.qualifying_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.qualifying_id_seq OWNER TO postgres;

--
-- TOC entry 3782 (class 0 OID 0)
-- Dependencies: 256
-- Name: qualifying_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.qualifying_id_seq OWNED BY public.qualifying.id;


--
-- TOC entry 255 (class 1259 OID 19561)
-- Name: races; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.races (
    id integer NOT NULL,
    race_ref character varying(255) NOT NULL,
    season_id integer NOT NULL,
    round integer NOT NULL,
    race_name text NOT NULL,
    race_date date,
    race_time time without time zone,
    circuit_id integer NOT NULL
);


ALTER TABLE public.races OWNER TO postgres;

--
-- TOC entry 3783 (class 0 OID 0)
-- Dependencies: 255
-- Name: TABLE races; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.races IS 'Corridas da Fórmula 1 por temporada';


--
-- TOC entry 3784 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN races.race_ref; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.races.race_ref IS 'Identificador único vindo de races.csv';


--
-- TOC entry 3785 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN races.round; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.races.round IS 'Rodada do campeonato (1, 2, 3, ..., 23)';


--
-- TOC entry 3786 (class 0 OID 0)
-- Dependencies: 255
-- Name: COLUMN races.race_time; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.races.race_time IS 'Hora local de início da corrida';


--
-- TOC entry 254 (class 1259 OID 19560)
-- Name: races_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.races_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.races_id_seq OWNER TO postgres;

--
-- TOC entry 3787 (class 0 OID 0)
-- Dependencies: 254
-- Name: races_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.races_id_seq OWNED BY public.races.id;


--
-- TOC entry 259 (class 1259 OID 19618)
-- Name: results; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.results (
    id integer NOT NULL,
    race_id integer NOT NULL,
    driver_id integer NOT NULL,
    constructor_id integer NOT NULL,
    grid integer,
    "position" character varying(5),
    position_order integer,
    points numeric(10,2),
    laps integer,
    status_id integer NOT NULL
);


ALTER TABLE public.results OWNER TO postgres;

--
-- TOC entry 3788 (class 0 OID 0)
-- Dependencies: 259
-- Name: TABLE results; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.results IS 'Resultados detalhados de cada piloto em cada corrida';


--
-- TOC entry 3789 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN results.grid; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.results.grid IS 'Posição de largada no grid';


--
-- TOC entry 3790 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN results."position"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.results."position" IS 'Posição final (1, 2, 3, ..., DNF, DNS, etc.)';


--
-- TOC entry 3791 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN results.position_order; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.results.position_order IS 'Ordem de chegada (numérica)';


--
-- TOC entry 3792 (class 0 OID 0)
-- Dependencies: 259
-- Name: COLUMN results.status_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.results.status_id IS 'Referência ao status da corrida';


--
-- TOC entry 258 (class 1259 OID 19617)
-- Name: results_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.results_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.results_id_seq OWNER TO postgres;

--
-- TOC entry 3793 (class 0 OID 0)
-- Dependencies: 258
-- Name: results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.results_id_seq OWNED BY public.results.id;


--
-- TOC entry 247 (class 1259 OID 19498)
-- Name: seasons; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seasons (
    id integer NOT NULL,
    year integer NOT NULL
);


ALTER TABLE public.seasons OWNER TO postgres;

--
-- TOC entry 3794 (class 0 OID 0)
-- Dependencies: 247
-- Name: TABLE seasons; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.seasons IS 'Temporadas da Fórmula 1';


--
-- TOC entry 3795 (class 0 OID 0)
-- Dependencies: 247
-- Name: COLUMN seasons.year; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.seasons.year IS 'Ano da temporada de F1';


--
-- TOC entry 246 (class 1259 OID 19497)
-- Name: seasons_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.seasons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.seasons_id_seq OWNER TO postgres;

--
-- TOC entry 3796 (class 0 OID 0)
-- Dependencies: 246
-- Name: seasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.seasons_id_seq OWNED BY public.seasons.id;


--
-- TOC entry 261 (class 1259 OID 19652)
-- Name: standings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.standings (
    id integer NOT NULL,
    season_id integer NOT NULL,
    round integer NOT NULL,
    "position" integer,
    points numeric(10,2),
    wins integer
);


ALTER TABLE public.standings OWNER TO postgres;

--
-- TOC entry 3797 (class 0 OID 0)
-- Dependencies: 261
-- Name: TABLE standings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.standings IS 'Classificações acumuladas por temporada e rodada';


--
-- TOC entry 3798 (class 0 OID 0)
-- Dependencies: 261
-- Name: COLUMN standings.round; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.standings.round IS 'Rodada do campeonato (0 = antes da primeira corrida)';


--
-- TOC entry 3799 (class 0 OID 0)
-- Dependencies: 261
-- Name: COLUMN standings."position"; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.standings."position" IS 'Posição na classificação do campeonato';


--
-- TOC entry 3800 (class 0 OID 0)
-- Dependencies: 261
-- Name: COLUMN standings.wins; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.standings.wins IS 'Número de vitórias acumuladas na temporada';


--
-- TOC entry 260 (class 1259 OID 19651)
-- Name: standings_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.standings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.standings_id_seq OWNER TO postgres;

--
-- TOC entry 3801 (class 0 OID 0)
-- Dependencies: 260
-- Name: standings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.standings_id_seq OWNED BY public.standings.id;


--
-- TOC entry 245 (class 1259 OID 19485)
-- Name: status; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.status (
    id integer NOT NULL,
    status text NOT NULL
);


ALTER TABLE public.status OWNER TO postgres;

--
-- TOC entry 3802 (class 0 OID 0)
-- Dependencies: 245
-- Name: TABLE status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.status IS 'Status possíveis de uma corrida (Finished, DNF, Accident, etc.)';


--
-- TOC entry 3803 (class 0 OID 0)
-- Dependencies: 245
-- Name: COLUMN status.status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.status.status IS 'Descrição textual da ocorrência vinda de results.csv';


--
-- TOC entry 244 (class 1259 OID 19484)
-- Name: status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.status_id_seq OWNER TO postgres;

--
-- TOC entry 3804 (class 0 OID 0)
-- Dependencies: 244
-- Name: status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.status_id_seq OWNED BY public.status.id;


--
-- TOC entry 230 (class 1259 OID 19348)
-- Name: time_zones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.time_zones (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    gmt_offset numeric(10,2),
    dst_offset numeric(10,2),
    raw_offset numeric(10,2)
);


ALTER TABLE public.time_zones OWNER TO postgres;

--
-- TOC entry 3805 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE time_zones; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.time_zones IS 'Fusos horários mundiais';


--
-- TOC entry 3806 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN time_zones.gmt_offset; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.time_zones.gmt_offset IS 'Diferença em horas do GMT (Greenwich Mean Time)';


--
-- TOC entry 3807 (class 0 OID 0)
-- Dependencies: 230
-- Name: COLUMN time_zones.raw_offset; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.time_zones.raw_offset IS 'Offset base sem considerar horário de verão';


--
-- TOC entry 229 (class 1259 OID 19347)
-- Name: time_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.time_zones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.time_zones_id_seq OWNER TO postgres;

--
-- TOC entry 3808 (class 0 OID 0)
-- Dependencies: 229
-- Name: time_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.time_zones_id_seq OWNED BY public.time_zones.id;


--
-- TOC entry 3433 (class 2604 OID 19452)
-- Name: airport_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airport_types ALTER COLUMN id SET DEFAULT nextval('public.airport_types_id_seq'::regclass);


--
-- TOC entry 3434 (class 2604 OID 19463)
-- Name: airports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports ALTER COLUMN id SET DEFAULT nextval('public.airports_id_seq'::regclass);


--
-- TOC entry 3444 (class 2604 OID 20702)
-- Name: airports_audit audit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports_audit ALTER COLUMN audit_id SET DEFAULT nextval('public.airports_audit_audit_id_seq'::regclass);


--
-- TOC entry 3437 (class 2604 OID 19512)
-- Name: circuits id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.circuits ALTER COLUMN id SET DEFAULT nextval('public.circuits_id_seq'::regclass);


--
-- TOC entry 3432 (class 2604 OID 19425)
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- TOC entry 3438 (class 2604 OID 19531)
-- Name: constructors id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructors ALTER COLUMN id SET DEFAULT nextval('public.constructors_id_seq'::regclass);


--
-- TOC entry 3426 (class 2604 OID 19315)
-- Name: continents id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.continents ALTER COLUMN id SET DEFAULT nextval('public.continents_id_seq'::regclass);


--
-- TOC entry 3427 (class 2604 OID 19329)
-- Name: countries id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries ALTER COLUMN id SET DEFAULT nextval('public.countries_id_seq'::regclass);


--
-- TOC entry 3439 (class 2604 OID 19548)
-- Name: drivers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers ALTER COLUMN id SET DEFAULT nextval('public.drivers_id_seq'::regclass);


--
-- TOC entry 3431 (class 2604 OID 19410)
-- Name: feature_codes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feature_codes ALTER COLUMN id SET DEFAULT nextval('public.feature_codes_id_seq'::regclass);


--
-- TOC entry 3430 (class 2604 OID 19373)
-- Name: iso_language_codes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.iso_language_codes ALTER COLUMN id SET DEFAULT nextval('public.iso_language_codes_id_seq'::regclass);


--
-- TOC entry 3429 (class 2604 OID 19362)
-- Name: language_names id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.language_names ALTER COLUMN id SET DEFAULT nextval('public.language_names_id_seq'::regclass);


--
-- TOC entry 3441 (class 2604 OID 19593)
-- Name: qualifying id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualifying ALTER COLUMN id SET DEFAULT nextval('public.qualifying_id_seq'::regclass);


--
-- TOC entry 3440 (class 2604 OID 19564)
-- Name: races id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.races ALTER COLUMN id SET DEFAULT nextval('public.races_id_seq'::regclass);


--
-- TOC entry 3442 (class 2604 OID 19621)
-- Name: results id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results ALTER COLUMN id SET DEFAULT nextval('public.results_id_seq'::regclass);


--
-- TOC entry 3436 (class 2604 OID 19501)
-- Name: seasons id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seasons ALTER COLUMN id SET DEFAULT nextval('public.seasons_id_seq'::regclass);


--
-- TOC entry 3443 (class 2604 OID 19655)
-- Name: standings id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.standings ALTER COLUMN id SET DEFAULT nextval('public.standings_id_seq'::regclass);


--
-- TOC entry 3435 (class 2604 OID 19488)
-- Name: status id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.status ALTER COLUMN id SET DEFAULT nextval('public.status_id_seq'::regclass);


--
-- TOC entry 3428 (class 2604 OID 19351)
-- Name: time_zones id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_zones ALTER COLUMN id SET DEFAULT nextval('public.time_zones_id_seq'::regclass);


--
-- TOC entry 3483 (class 2606 OID 19456)
-- Name: airport_types airport_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airport_types
    ADD CONSTRAINT airport_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3485 (class 2606 OID 19458)
-- Name: airport_types airport_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airport_types
    ADD CONSTRAINT airport_types_type_key UNIQUE (type);


--
-- TOC entry 3534 (class 2606 OID 20710)
-- Name: airports_audit airports_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports_audit
    ADD CONSTRAINT airports_audit_pkey PRIMARY KEY (audit_id);


--
-- TOC entry 3487 (class 2606 OID 19473)
-- Name: airports airports_ident_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports
    ADD CONSTRAINT airports_ident_key UNIQUE (ident);


--
-- TOC entry 3489 (class 2606 OID 19471)
-- Name: airports airports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports
    ADD CONSTRAINT airports_pkey PRIMARY KEY (id);


--
-- TOC entry 3499 (class 2606 OID 19521)
-- Name: circuits circuits_circuit_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.circuits
    ADD CONSTRAINT circuits_circuit_ref_key UNIQUE (circuit_ref);


--
-- TOC entry 3501 (class 2606 OID 19519)
-- Name: circuits circuits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.circuits
    ADD CONSTRAINT circuits_pkey PRIMARY KEY (id);


--
-- TOC entry 3480 (class 2606 OID 19432)
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- TOC entry 3503 (class 2606 OID 19541)
-- Name: constructors constructors_constructor_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructors
    ADD CONSTRAINT constructors_constructor_ref_key UNIQUE (constructor_ref);


--
-- TOC entry 3505 (class 2606 OID 19543)
-- Name: constructors constructors_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructors
    ADD CONSTRAINT constructors_name_key UNIQUE (name);


--
-- TOC entry 3507 (class 2606 OID 19539)
-- Name: constructors constructors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructors
    ADD CONSTRAINT constructors_pkey PRIMARY KEY (id);


--
-- TOC entry 3446 (class 2606 OID 19322)
-- Name: continents continents_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.continents
    ADD CONSTRAINT continents_code_key UNIQUE (code);


--
-- TOC entry 3448 (class 2606 OID 19324)
-- Name: continents continents_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.continents
    ADD CONSTRAINT continents_name_key UNIQUE (name);


--
-- TOC entry 3450 (class 2606 OID 19320)
-- Name: continents continents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.continents
    ADD CONSTRAINT continents_pkey PRIMARY KEY (id);


--
-- TOC entry 3452 (class 2606 OID 19339)
-- Name: countries countries_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_code_key UNIQUE (code);


--
-- TOC entry 3454 (class 2606 OID 19341)
-- Name: countries countries_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_name_key UNIQUE (name);


--
-- TOC entry 3456 (class 2606 OID 19337)
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- TOC entry 3474 (class 2606 OID 19395)
-- Name: country_languages country_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country_languages
    ADD CONSTRAINT country_languages_pkey PRIMARY KEY (country_id, language_id);


--
-- TOC entry 3509 (class 2606 OID 19559)
-- Name: drivers drivers_driver_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_driver_ref_key UNIQUE (driver_ref);


--
-- TOC entry 3511 (class 2606 OID 19557)
-- Name: drivers drivers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT drivers_pkey PRIMARY KEY (id);


--
-- TOC entry 3476 (class 2606 OID 19418)
-- Name: feature_codes feature_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feature_codes
    ADD CONSTRAINT feature_codes_pkey PRIMARY KEY (id);


--
-- TOC entry 3466 (class 2606 OID 19383)
-- Name: iso_language_codes iso_language_codes_iso_639_1_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.iso_language_codes
    ADD CONSTRAINT iso_language_codes_iso_639_1_key UNIQUE (iso_639_1);


--
-- TOC entry 3468 (class 2606 OID 19381)
-- Name: iso_language_codes iso_language_codes_iso_639_2_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.iso_language_codes
    ADD CONSTRAINT iso_language_codes_iso_639_2_key UNIQUE (iso_639_2);


--
-- TOC entry 3470 (class 2606 OID 19379)
-- Name: iso_language_codes iso_language_codes_iso_639_3_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.iso_language_codes
    ADD CONSTRAINT iso_language_codes_iso_639_3_key UNIQUE (iso_639_3);


--
-- TOC entry 3472 (class 2606 OID 19377)
-- Name: iso_language_codes iso_language_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.iso_language_codes
    ADD CONSTRAINT iso_language_codes_pkey PRIMARY KEY (id);


--
-- TOC entry 3462 (class 2606 OID 19368)
-- Name: language_names language_names_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.language_names
    ADD CONSTRAINT language_names_name_key UNIQUE (name);


--
-- TOC entry 3464 (class 2606 OID 19366)
-- Name: language_names language_names_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.language_names
    ADD CONSTRAINT language_names_pkey PRIMARY KEY (id);


--
-- TOC entry 3532 (class 2606 OID 19689)
-- Name: constructor_standings pk_constructor_standings; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructor_standings
    ADD CONSTRAINT pk_constructor_standings PRIMARY KEY (standing_id, constructor_id);


--
-- TOC entry 3530 (class 2606 OID 19672)
-- Name: driver_standings pk_driver_standings; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_standings
    ADD CONSTRAINT pk_driver_standings PRIMARY KEY (standing_id, driver_id);


--
-- TOC entry 3520 (class 2606 OID 19599)
-- Name: qualifying qualifying_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualifying
    ADD CONSTRAINT qualifying_pkey PRIMARY KEY (id);


--
-- TOC entry 3514 (class 2606 OID 19574)
-- Name: races races_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.races
    ADD CONSTRAINT races_pkey PRIMARY KEY (id);


--
-- TOC entry 3516 (class 2606 OID 19576)
-- Name: races races_race_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.races
    ADD CONSTRAINT races_race_ref_key UNIQUE (race_ref);


--
-- TOC entry 3524 (class 2606 OID 19628)
-- Name: results results_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results
    ADD CONSTRAINT results_pkey PRIMARY KEY (id);


--
-- TOC entry 3495 (class 2606 OID 19505)
-- Name: seasons seasons_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_pkey PRIMARY KEY (id);


--
-- TOC entry 3497 (class 2606 OID 19507)
-- Name: seasons seasons_year_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seasons
    ADD CONSTRAINT seasons_year_key UNIQUE (year);


--
-- TOC entry 3528 (class 2606 OID 19660)
-- Name: standings standings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_pkey PRIMARY KEY (id);


--
-- TOC entry 3491 (class 2606 OID 19494)
-- Name: status status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);


--
-- TOC entry 3493 (class 2606 OID 19496)
-- Name: status status_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_status_key UNIQUE (status);


--
-- TOC entry 3458 (class 2606 OID 19357)
-- Name: time_zones time_zones_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_zones
    ADD CONSTRAINT time_zones_name_key UNIQUE (name);


--
-- TOC entry 3460 (class 2606 OID 19355)
-- Name: time_zones time_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.time_zones
    ADD CONSTRAINT time_zones_pkey PRIMARY KEY (id);


--
-- TOC entry 3478 (class 2606 OID 19420)
-- Name: feature_codes uq_feature_codes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.feature_codes
    ADD CONSTRAINT uq_feature_codes UNIQUE (feature_class, feature_code);


--
-- TOC entry 3522 (class 2606 OID 19601)
-- Name: qualifying uq_qualifying_race_driver; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualifying
    ADD CONSTRAINT uq_qualifying_race_driver UNIQUE (race_id, driver_id);


--
-- TOC entry 3518 (class 2606 OID 19578)
-- Name: races uq_races_season_round; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.races
    ADD CONSTRAINT uq_races_season_round UNIQUE (season_id, round);


--
-- TOC entry 3526 (class 2606 OID 19630)
-- Name: results uq_results_race_driver; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results
    ADD CONSTRAINT uq_results_race_driver UNIQUE (race_id, driver_id);


--
-- TOC entry 3481 (class 1259 OID 21056)
-- Name: idx_cities_name_pattern; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cities_name_pattern ON public.cities USING btree (name text_pattern_ops);


--
-- TOC entry 3512 (class 1259 OID 21055)
-- Name: idx_drivers_name_hash; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_drivers_name_hash ON public.drivers USING hash (((((given_name)::text || ' '::text) || (family_name)::text)));


--
-- TOC entry 3561 (class 2620 OID 20712)
-- Name: airports tr_airportsaudit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_airportsaudit AFTER INSERT OR DELETE OR UPDATE ON public.airports FOR EACH ROW EXECUTE FUNCTION public.auditaeroporto();


--
-- TOC entry 3562 (class 2620 OID 20714)
-- Name: qualifying tr_qualifying; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tr_qualifying BEFORE INSERT OR UPDATE OF "position" ON public.qualifying FOR EACH ROW EXECUTE FUNCTION public.verificaqualifying();


--
-- TOC entry 3542 (class 2606 OID 19479)
-- Name: airports fk_airports_city; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports
    ADD CONSTRAINT fk_airports_city FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- TOC entry 3543 (class 2606 OID 19474)
-- Name: airports fk_airports_type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airports
    ADD CONSTRAINT fk_airports_type FOREIGN KEY (airport_type_id) REFERENCES public.airport_types(id);


--
-- TOC entry 3544 (class 2606 OID 19522)
-- Name: circuits fk_circuits_city; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.circuits
    ADD CONSTRAINT fk_circuits_city FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- TOC entry 3539 (class 2606 OID 19443)
-- Name: cities fk_cities_country; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT fk_cities_country FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- TOC entry 3540 (class 2606 OID 19433)
-- Name: cities fk_cities_feature_code; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT fk_cities_feature_code FOREIGN KEY (feature_code_id) REFERENCES public.feature_codes(id);


--
-- TOC entry 3541 (class 2606 OID 19438)
-- Name: cities fk_cities_time_zone; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT fk_cities_time_zone FOREIGN KEY (time_zone_id) REFERENCES public.time_zones(id);


--
-- TOC entry 3559 (class 2606 OID 19695)
-- Name: constructor_standings fk_constructor_standings_constructor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructor_standings
    ADD CONSTRAINT fk_constructor_standings_constructor FOREIGN KEY (constructor_id) REFERENCES public.constructors(id);


--
-- TOC entry 3560 (class 2606 OID 19690)
-- Name: constructor_standings fk_constructor_standings_standings; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructor_standings
    ADD CONSTRAINT fk_constructor_standings_standings FOREIGN KEY (standing_id) REFERENCES public.standings(id);


--
-- TOC entry 3545 (class 2606 OID 20086)
-- Name: constructors fk_constructors_country; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructors
    ADD CONSTRAINT fk_constructors_country FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- TOC entry 3535 (class 2606 OID 19342)
-- Name: countries fk_countries_continent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT fk_countries_continent FOREIGN KEY (continent_id) REFERENCES public.continents(id);


--
-- TOC entry 3537 (class 2606 OID 19396)
-- Name: country_languages fk_country_languages_country; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country_languages
    ADD CONSTRAINT fk_country_languages_country FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- TOC entry 3538 (class 2606 OID 19401)
-- Name: country_languages fk_country_languages_language; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.country_languages
    ADD CONSTRAINT fk_country_languages_language FOREIGN KEY (language_id) REFERENCES public.language_names(id);


--
-- TOC entry 3557 (class 2606 OID 19678)
-- Name: driver_standings fk_driver_standings_driver; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_standings
    ADD CONSTRAINT fk_driver_standings_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(id);


--
-- TOC entry 3558 (class 2606 OID 19673)
-- Name: driver_standings fk_driver_standings_standings; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.driver_standings
    ADD CONSTRAINT fk_driver_standings_standings FOREIGN KEY (standing_id) REFERENCES public.standings(id);


--
-- TOC entry 3546 (class 2606 OID 20081)
-- Name: drivers fk_drivers_country; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.drivers
    ADD CONSTRAINT fk_drivers_country FOREIGN KEY (country_id) REFERENCES public.countries(id);


--
-- TOC entry 3536 (class 2606 OID 19384)
-- Name: iso_language_codes fk_iso_language_codes_language; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.iso_language_codes
    ADD CONSTRAINT fk_iso_language_codes_language FOREIGN KEY (language_id) REFERENCES public.language_names(id);


--
-- TOC entry 3549 (class 2606 OID 19612)
-- Name: qualifying fk_qualifying_constructor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualifying
    ADD CONSTRAINT fk_qualifying_constructor FOREIGN KEY (constructor_id) REFERENCES public.constructors(id);


--
-- TOC entry 3550 (class 2606 OID 19607)
-- Name: qualifying fk_qualifying_driver; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualifying
    ADD CONSTRAINT fk_qualifying_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(id);


--
-- TOC entry 3551 (class 2606 OID 19602)
-- Name: qualifying fk_qualifying_race; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.qualifying
    ADD CONSTRAINT fk_qualifying_race FOREIGN KEY (race_id) REFERENCES public.races(id);


--
-- TOC entry 3547 (class 2606 OID 19584)
-- Name: races fk_races_circuit; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.races
    ADD CONSTRAINT fk_races_circuit FOREIGN KEY (circuit_id) REFERENCES public.circuits(id);


--
-- TOC entry 3548 (class 2606 OID 19579)
-- Name: races fk_races_season; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.races
    ADD CONSTRAINT fk_races_season FOREIGN KEY (season_id) REFERENCES public.seasons(id);


--
-- TOC entry 3552 (class 2606 OID 19641)
-- Name: results fk_results_constructor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results
    ADD CONSTRAINT fk_results_constructor FOREIGN KEY (constructor_id) REFERENCES public.constructors(id);


--
-- TOC entry 3553 (class 2606 OID 19636)
-- Name: results fk_results_driver; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results
    ADD CONSTRAINT fk_results_driver FOREIGN KEY (driver_id) REFERENCES public.drivers(id);


--
-- TOC entry 3554 (class 2606 OID 19631)
-- Name: results fk_results_race; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results
    ADD CONSTRAINT fk_results_race FOREIGN KEY (race_id) REFERENCES public.races(id);


--
-- TOC entry 3555 (class 2606 OID 19646)
-- Name: results fk_results_status; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.results
    ADD CONSTRAINT fk_results_status FOREIGN KEY (status_id) REFERENCES public.status(id);


--
-- TOC entry 3556 (class 2606 OID 19661)
-- Name: standings fk_standings_season; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT fk_standings_season FOREIGN KEY (season_id) REFERENCES public.seasons(id);


--
-- TOC entry 3721 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2026-06-07 14:42:17 -03

--
-- PostgreSQL database dump complete
--

\unrestrict xWCjdH4sZ7CXNVQkR1IhGav55cz5E8d9KkLhmAOJX2GzKz00qsmJ9oglG2TbNxW

