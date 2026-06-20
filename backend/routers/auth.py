"""Auth endpoints: login and logout, both audited in USERS_LOG."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from queries import auth_queries
from security import create_token, get_current_user

router = APIRouter(prefix="/api/auth", tags=["auth"])


class LoginRequest(BaseModel):
    login: str
    password: str


@router.post("/login")
def login(body: LoginRequest):
    user = auth_queries.authenticate(body.login.strip(), body.password)
    if user is None:
        raise HTTPException(status_code=401, detail="Login ou senha incorretos.")

    # Audit requirement: every LOGIN goes to USERS_LOG.
    auth_queries.log_action(user["userid"], "LOGIN")

    info = auth_queries.get_display_info(user["type"], user["original_id"])
    token = create_token(user["userid"], user["login"], user["type"], user["original_id"])
    return {
        "token": token,
        "user": {
            "userid": user["userid"],
            "login": user["login"],
            "type": user["type"],
            "original_id": user["original_id"],
            "display_name": info["display_name"],
        },
    }


@router.post("/logout")
def logout(user: dict = Depends(get_current_user)):
    # Audit requirement: every LOGOUT goes to USERS_LOG.
    auth_queries.log_action(user["userid"], "LOGOUT")
    return {"ok": True}
