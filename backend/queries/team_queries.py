"""Team-scoped SQL: dashboard, driver lookup, bulk driver insert, Reports 4–5.

Every function receives the logged-in team's constructor id, so a Team user
can only ever read data in their own scope (access control enforced by the
router + these parameterized queries).
"""

from db import db_cursor


# ---------------------------------------------------------------------------
# Dashboard — stored functions required by the statement (section 4).
# ---------------------------------------------------------------------------

def get_dashboard(constructor_id: int) -> dict:
    with db_cursor() as cur:
        cur.execute("SELECT name FROM constructors WHERE id = %s", (constructor_id,))
        team = cur.fetchone()

        # Stored functions fn_team_* defined in sql/03_functions.sql.
        cur.execute(
            """
            SELECT fn_team_wins(%(cid)s)         AS wins,
                   fn_team_driver_count(%(cid)s) AS driver_count,
                   y.first_year,
                   y.last_year
            FROM fn_team_active_years(%(cid)s) AS y
            """,
            {"cid": constructor_id},
        )
        stats = cur.fetchone()

    return {"team_name": team["name"] if team else "?", **(stats or {})}


# ---------------------------------------------------------------------------
# Action: query driver by last name (only drivers who raced for this team).
# ---------------------------------------------------------------------------

def find_drivers_by_surname(constructor_id: int, family_name: str) -> list[dict]:
    with db_cursor() as cur:
        # Semi-join via EXISTS on RESULTS: "has raced for the team"
        # (statement tip). Case-insensitive match supported by the
        # idx_drivers_family_name_lower index.
        cur.execute(
            """
            SELECT d.given_name || ' ' || d.family_name AS full_name,
                   d.date_of_birth,
                   COALESCE(co.name, d.nationality) AS country
            FROM drivers d
            LEFT JOIN countries co ON co.id = d.country_id
            WHERE LOWER(d.family_name) = LOWER(%s)
              AND EXISTS (
                    SELECT 1 FROM results r
                    WHERE r.driver_id = d.id
                      AND r.constructor_id = %s
              )
            ORDER BY full_name
            """,
            (family_name, constructor_id),
        )
        return cur.fetchall()


# ---------------------------------------------------------------------------
# Action: insert drivers from an uploaded file.
# ---------------------------------------------------------------------------

def driver_name_exists(given_name: str, family_name: str) -> bool:
    """Statement: before inserting, check no driver has the same full name."""
    with db_cursor() as cur:
        cur.execute(
            """
            SELECT 1
            FROM drivers
            WHERE LOWER(given_name)  = LOWER(%s)
              AND LOWER(family_name) = LOWER(%s)
            """,
            (given_name, family_name),
        )
        return cur.fetchone() is not None


def insert_driver_from_file(driver_ref: str, given_name: str, family_name: str,
                            date_of_birth: str | None, country_id: int) -> dict:
    """Insert one driver row; the trigger creates the USERS row (or raises,
    cancelling this driver's insertion if the login already exists)."""
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
            raise ValueError(f"País com id {country_id} não existe.")
        return row


# ---------------------------------------------------------------------------
# Reports 4 and 5 — stored functions receiving the team id (statement
# recommendation), backed by idx_results_constructor.
# ---------------------------------------------------------------------------

def report4_driver_wins(constructor_id: int) -> list[dict]:
    with db_cursor() as cur:
        cur.execute(
            "SELECT full_name, wins FROM fn_report4_team_driver_wins(%s)",
            (constructor_id,),
        )
        return cur.fetchall()


def report5_status_counts(constructor_id: int) -> list[dict]:
    with db_cursor() as cur:
        cur.execute(
            "SELECT status, total FROM fn_report5_team_status_counts(%s)",
            (constructor_id,),
        )
        return cur.fetchall()
