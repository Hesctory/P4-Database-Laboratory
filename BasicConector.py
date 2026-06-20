"""Teste rápido de conexão. Reaproveita a configuração de `backend/db.py`,
que lê as credenciais do `.env` (ver `.env.example`) — sem segredos no código.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "backend"))

import psycopg2

from db import DB_CONFIG

conn = psycopg2.connect(**DB_CONFIG)
cursor = conn.cursor()
print("Conexão OK:", DB_CONFIG["database"])
