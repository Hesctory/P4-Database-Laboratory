"""Apply the project's SQL scripts (backend/sql/*.sql) in order.

Usage:  python3 setup_db.py
Idempotent: scripts use IF NOT EXISTS / CREATE OR REPLACE / ON CONFLICT.
"""

from pathlib import Path

import psycopg2

from db import DB_CONFIG

SQL_DIR = Path(__file__).parent / "sql"


def main() -> None:
    conn = psycopg2.connect(**DB_CONFIG)
    conn.autocommit = False
    try:
        with conn.cursor() as cur:
            for script in sorted(SQL_DIR.glob("*.sql")):
                print(f"Applying {script.name} ...")
                cur.execute(script.read_text())
        conn.commit()
        print("All scripts applied successfully.")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()
