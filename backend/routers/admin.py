"""Admin endpoints: dashboard, team/driver registration, Reports 1–3.

All routes are restricted to the 'Admin' user type (require_type).
"""

import psycopg2
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from queries import admin_queries
from security import require_type

router = APIRouter(
    prefix="/api/admin",
    tags=["admin"],
    dependencies=[Depends(require_type("Admin"))],
)


class TeamCreate(BaseModel):
    constructor_ref: str
    name: str
    country_id: int
    wikipedia_url: str | None = None


class DriverCreate(BaseModel):
    driver_ref: str
    given_name: str
    family_name: str
    date_of_birth: str | None = None  # ISO yyyy-mm-dd
    country_id: int


@router.get("/dashboard")
def dashboard():
    return admin_queries.get_dashboard()


@router.get("/countries")
def countries():
    return admin_queries.list_countries()


@router.post("/teams")
def create_team(body: TeamCreate):
    try:
        row = admin_queries.insert_team(
            body.constructor_ref.strip(), body.name.strip(),
            body.country_id, body.wikipedia_url,
        )
    except psycopg2.errors.RaiseException as e:
        # Trigger cancelled the insert (duplicate generated login).
        raise HTTPException(status_code=409, detail=str(e.diag.message_primary))
    except psycopg2.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Já existe uma equipe com esse ref ou nome.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"ok": True, "team": row}


@router.post("/drivers")
def create_driver(body: DriverCreate):
    try:
        row = admin_queries.insert_driver(
            body.driver_ref.strip(), body.given_name.strip(), body.family_name.strip(),
            body.date_of_birth or None, body.country_id,
        )
    except psycopg2.errors.RaiseException as e:
        raise HTTPException(status_code=409, detail=str(e.diag.message_primary))
    except psycopg2.errors.UniqueViolation:
        raise HTTPException(status_code=409, detail="Já existe um piloto com esse driver_ref.")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    return {"ok": True, "driver": row}


@router.get("/reports/1")
def report1():
    return admin_queries.report1_results_by_status()


@router.get("/reports/2")
def report2(city: str):
    if not city.strip():
        raise HTTPException(status_code=400, detail="Informe o nome da cidade.")
    return admin_queries.report2_airports_near_city(city.strip())


@router.get("/reports/3")
def report3():
    return admin_queries.report3_hierarchical()
