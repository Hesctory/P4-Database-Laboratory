"""Driver-scoped SQL: dashboard and Reports 6–7.

Driver users are read-only (statement, section 3): only SELECTs here, all
parameterized by the logged-in driver's id.
"""

from db import db_cursor


def get_dashboard(driver_id: int) -> dict:
    with db_cursor() as cur:
        # Full name + most recent team the driver raced for (results → races
        # ordered by date, LIMIT 1).
        cur.execute(
            """
            SELECT d.given_name || ' ' || d.family_name AS driver_name,
                   (SELECT co.name
                    FROM results r
                    JOIN races ra ON ra.id = r.race_id
                    JOIN constructors co ON co.id = r.constructor_id
                    WHERE r.driver_id = d.id
                    ORDER BY ra.race_date DESC NULLS LAST
                    LIMIT 1) AS team_name
            FROM drivers d
            WHERE d.id = %s
            """,
            (driver_id,),
        )
        info = cur.fetchone()

        # Stored function: first/last year with data in RESULTS.
        cur.execute(
            "SELECT first_year, last_year FROM fn_driver_active_years(%s)",
            (driver_id,),
        )
        years = cur.fetchone()

        # Stored function: per-year, per-circuit points/wins/races.
        cur.execute(
            """
            SELECT year, circuit_name, points, wins, races
            FROM fn_driver_yearly_circuit_stats(%s)
            """,
            (driver_id,),
        )
        stats = cur.fetchall()

    return {**(info or {}), **(years or {}), "circuit_stats": stats}


def report6_points_by_year(driver_id: int) -> list[dict]:
    """Report 6: points per year with the races where they were obtained
    (stored function with window aggregation, backed by idx_results_driver)."""
    with db_cursor() as cur:
        cur.execute(
            """
            SELECT year, race_name, race_date, points, year_total
            FROM fn_report6_driver_points_by_year(%s)
            """,
            (driver_id,),
        )
        return cur.fetchall()


def report7_status_counts(driver_id: int) -> list[dict]:
    with db_cursor() as cur:
        cur.execute(
            "SELECT status, total FROM fn_report7_driver_status_counts(%s)",
            (driver_id,),
        )
        return cur.fetchall()
