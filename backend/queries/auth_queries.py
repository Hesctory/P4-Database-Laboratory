"""Authentication SQL.

Passwords are verified inside PostgreSQL with pgcrypto:
`password = crypt(%s, password)` re-hashes the candidate password with the
stored bcrypt salt and compares hashes — the plain-text password never
touches the USERS table.
"""

from db import db_cursor


def authenticate(login: str, password: str) -> dict | None:
    """Return the user row if login/password match, else None."""
    with db_cursor() as cur:
        # Access control: bcrypt comparison done by pgcrypto's crypt().
        cur.execute(
            """
            SELECT userid, login, type, original_id
            FROM users
            WHERE login = %s
              AND password = crypt(%s, password)
            """,
            (login, password),
        )
        return cur.fetchone()


def log_action(userid: int, action: str) -> None:
    """Audit trail: record LOGIN/LOGOUT in USERS_LOG (project requirement 1.6)."""
    with db_cursor() as cur:
        cur.execute(
            """
            INSERT INTO users_log (userid, action)
            VALUES (%s, %s)
            """,
            (userid, action),
        )


def get_display_info(user_type: str, original_id: int | None) -> dict:
    """Resolve the human-readable name shown on the dashboard header."""
    if user_type == "Admin" or original_id is None:
        return {"display_name": "Administrador"}

    with db_cursor() as cur:
        if user_type == "Team":
            cur.execute(
                "SELECT name AS display_name FROM constructors WHERE id = %s",
                (original_id,),
            )
        else:  # Driver
            cur.execute(
                """
                SELECT given_name || ' ' || family_name AS display_name
                FROM drivers
                WHERE id = %s
                """,
                (original_id,),
            )
        row = cur.fetchone()
        return row or {"display_name": "?"}
