"""Authentication helpers (JWT).

Access control concept: after login the backend issues a signed JWT
carrying userid, type and original_id. Every protected endpoint validates
the token and the user *type*, so a Driver can never call Team/Admin
endpoints — the scope restriction required by the project statement is
enforced server-side, not only hidden in the UI.
"""

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

import jwt
from dotenv import load_dotenv
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

# Segredo de assinatura dos tokens — vem do ambiente / `.env` (ver `.env.example`).
# Fallback inseguro apenas para dev local.
load_dotenv(Path(__file__).resolve().parent.parent / ".env")
JWT_SECRET = os.getenv("JWT_SECRET", "dev-insecure-change-me")
JWT_ALGORITHM = "HS256"
TOKEN_TTL_HOURS = 8

_bearer = HTTPBearer(auto_error=False)


def create_token(userid: int, login: str, user_type: str, original_id: int | None) -> str:
    payload = {
        "sub": str(userid),
        "login": login,
        "type": user_type,
        "original_id": original_id,
        "exp": datetime.now(timezone.utc) + timedelta(hours=TOKEN_TTL_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    """Decode and validate the Bearer token; returns the token payload."""
    if credentials is None:
        raise HTTPException(status_code=401, detail="Não autenticado.")
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Sessão expirada. Faça login novamente.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido.")
    return {
        "userid": int(payload["sub"]),
        "login": payload["login"],
        "type": payload["type"],
        "original_id": payload["original_id"],
    }


def require_type(*allowed_types: str):
    """Dependency factory restricting an endpoint to specific user types."""

    def checker(user: dict = Depends(get_current_user)) -> dict:
        if user["type"] not in allowed_types:
            raise HTTPException(status_code=403, detail="Acesso negado para este tipo de usuário.")
        return user

    return checker
