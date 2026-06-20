"""Admin SQL: dashboard, registration of teams/drivers and Reports 1–3.

All statements are explicit raw SQL (project requirement). The dashboard
reads from the views defined in sql/04_views.sql; registrations rely on
the triggers of sql/02_triggers.sql to create the USERS rows.
"""

from db import db_cursor


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

def get_dashboard() -> dict:
    with db_cursor() as cur:
        # Totals: three scalar aggregations in one round-trip.
        cur.execute(
            """
            SELECT (SELECT COUNT(*) FROM drivers)      AS total_drivers,
                   (SELECT COUNT(*) FROM constructors) AS total_teams,
                   (SELECT COUNT(*) FROM seasons)      AS total_seasons
            """
        )
        totals = cur.fetchone()

        cur.execute("SELECT year FROM vw_latest_season")
        latest = cur.fetchone()

        # Races of the most recent season (view: join races/circuits/results).
        cur.execute(
            """
            SELECT round, race_name, circuit_name, race_date, race_time, laps
            FROM vw_latest_season_races
            """
        )
        races = cur.fetchall()

        # Teams of the most recent season with total points (view).
        cur.execute("SELECT team_name, total_points FROM vw_latest_season_team_points")
        teams = cur.fetchall()

        # Drivers of the most recent season with total points (view).
        cur.execute("SELECT driver_name, total_points FROM vw_latest_season_driver_points")
        drivers = cur.fetchall()

    return {
        "totals": totals,
        "latest_season": latest["year"] if latest else None,
        "races": races,
        "teams": teams,
        "drivers": drivers,
    }


# ---------------------------------------------------------------------------
# Registration forms (the triggers create the matching USERS rows; a
# duplicate generated login raises an exception that cancels the INSERT).
# ---------------------------------------------------------------------------

def list_countries() -> list[dict]:
    with db_cursor() as cur:
        cur.execute("SELECT id, name FROM countries ORDER BY name")
        return cur.fetchall()


def insert_team(constructor_ref: str, name: str, country_id: int, wikipedia_url: str | None) -> dict:
    with db_cursor() as cur:
        # `nationality` is NOT NULL in the legacy schema, so it is derived
        # from the chosen country (COUNTRIES.nationality).
        cur.execute(
            """
            INSERT INTO constructors (constructor_ref, name, nationality, wikipedia_url, country_id)
            SELECT %s, %s, COALESCE(c.nationality, c.name), %s, c.id
            FROM countries c
            WHERE c.id = %s
            RETURNING id, constructor_ref, name
            """,
            (constructor_ref, name, wikipedia_url, country_id),
        )
        row = cur.fetchone()
        if row is None:
            raise ValueError("País informado não existe.")
        return row


def insert_driver(driver_ref: str, given_name: str, family_name: str,
                  date_of_birth: str | None, country_id: int) -> dict:
    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO drivers (driver_ref, given_name, family_name, nationality, date_of_birth, country_id)
            SELECT %s, %s, %s, COALESCE(c.nationality, c.name), %s, c.id
            FROM countries c
            WHERE c.id = %s
            RETURNING id, driver_ref, given_name, family_name
            """,
            (driver_ref, given_name, family_name, date_of_birth, country_id),
        )
        row = cur.fetchone()
        if row is None:
            raise ValueError("País informado não existe.")
        return row


# ---------------------------------------------------------------------------
# Reports 1–3
# ---------------------------------------------------------------------------

def report1_results_by_status() -> list[dict]:
    """Report 1: count of results per status (view with JOIN + GROUP BY)."""
    with db_cursor() as cur:
        cur.execute("SELECT status, total FROM vw_results_by_status")
        return cur.fetchall()


def report2_airports_near_city(city_name: str) -> list[dict]:
    """Report 2: Brazilian medium/large airports within 100 km of each
    Brazilian city with the given name (stored function + GiST index)."""
    with db_cursor() as cur:
        cur.execute(
            """
            SELECT city_name, iata_code, airport_name, airport_city,
                   distance_km, airport_type
            FROM fn_report2_airports_near_city(%s)
            """,
            (city_name,),
        )
        return cur.fetchall()


def report3_hierarchical() -> dict:
    """Report 3: teams with driver counts + 3-level hierarchical race report."""
    with db_cursor() as cur:
        # Teams and their number of distinct drivers (view).
        cur.execute("SELECT team_name, driver_count FROM vw_teams_driver_count")
        teams = cur.fetchall()

        # Level 1: total number of registered races.
        cur.execute("SELECT COUNT(*) AS total_races FROM races")
        total_races = cur.fetchone()["total_races"]

        # Level 2: races per circuit with MIN/AVG/MAX laps recorded in results.
        cur.execute(
            """
            SELECT c.id AS circuit_id,
                   c.name AS circuit_name,
                   COUNT(DISTINCT ra.id) AS race_count,
                   MIN(r.laps)                 AS min_laps,
                   ROUND(AVG(r.laps), 1)       AS avg_laps,
                   MAX(r.laps)                 AS max_laps
            FROM circuits c
            JOIN races ra   ON ra.circuit_id = c.id
            LEFT JOIN results r ON r.race_id = ra.id
            GROUP BY c.id, c.name
            ORDER BY c.name
            """
        )
        circuits = cur.fetchall()

        # Level 3: per race per circuit — laps recorded and participating drivers.
        cur.execute(
            """
            SELECT ra.circuit_id,
                   ra.race_name,
                   s.year,
                   MAX(r.laps)                 AS laps,
                   COUNT(DISTINCT r.driver_id) AS driver_count
            FROM races ra
            JOIN seasons s ON s.id = ra.season_id
            LEFT JOIN results r ON r.race_id = ra.id
            GROUP BY ra.id, ra.circuit_id, ra.race_name, s.year
            ORDER BY ra.circuit_id, s.year
            """
        )
        races = cur.fetchall()

    return {
        "teams": teams,
        "total_races": total_races,
        "circuits": circuits,
        "races": races,
    }
