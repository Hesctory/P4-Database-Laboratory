"""Database connection management (psycopg2 — raw SQL, no ORM).

A small connection pool is shared by the whole application. Every query
function borrows a connection through `db_cursor()`, which commits on
success and rolls back on error, so transactional behaviour (e.g. trigger
exceptions cancelling an INSERT) is preserved.
"""

import os
from contextlib import contextmanager
from pathlib import Path

import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool

# Credenciais vêm de variáveis de ambiente / arquivo `.env` na raiz do projeto
# (ver `.env.example`). Nunca colocar segredos diretamente no código.
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "database": os.getenv("DB_NAME", "T1 work"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

_pool: SimpleConnectionPool | None = None


def get_pool() -> SimpleConnectionPool:
    global _pool
    if _pool is None:
        _pool = SimpleConnectionPool(minconn=1, maxconn=10, **DB_CONFIG)
    return _pool


@contextmanager
def db_cursor():
    """Yield a RealDictCursor; commit on success, rollback on any error."""
    pool = get_pool()
    conn = pool.getconn()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        pool.putconn(conn)
