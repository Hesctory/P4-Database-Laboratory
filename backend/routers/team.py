"""Team endpoints: dashboard, driver lookup, file-based driver insert,
Reports 4–5. Restricted to the 'Team' type; every query is parameterized
with the logged-in team's original_id, so a team can only see its own data.
"""

import psycopg2
from fastapi import APIRouter, Depends, HTTPException, UploadFile

from queries import team_queries
from security import require_type

router = APIRouter(prefix="/api/team", tags=["team"])

team_user = Depends(require_type("Team"))


@router.get("/dashboard")
def dashboard(user: dict = team_user):
    return team_queries.get_dashboard(user["original_id"])


@router.get("/drivers/by-surname")
def drivers_by_surname(family_name: str, user: dict = team_user):
    if not family_name.strip():
        raise HTTPException(status_code=400, detail="Informe o sobrenome do piloto.")
    return team_queries.find_drivers_by_surname(user["original_id"], family_name.strip())


@router.post("/drivers/upload")
async def upload_drivers(file: UploadFile, user: dict = team_user):
    """Insert drivers from a text file — one driver per line:
    driver_ref,given_name,family_name,date_of_birth,country_id

    Each line is processed independently: duplicates (same full name, per the
    statement) or trigger rejections cancel that driver's insertion and are
    reported back; valid lines are inserted (DRIVERS row + USERS row via trigger).
    """
    raw = (await file.read()).decode("utf-8", errors="replace")
    inserted: list[str] = []
    errors: list[str] = []

    for line_no, line in enumerate(raw.splitlines(), start=1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split(",")]
        if len(parts) != 5:
            errors.append(f"Linha {line_no}: esperados 5 campos, encontrados {len(parts)}.")
            continue
        driver_ref, given_name, family_name, date_of_birth, country_id_s = parts

        try:
            country_id = int(country_id_s)
        except ValueError:
            errors.append(f"Linha {line_no}: country_id inválido ('{country_id_s}').")
            continue

        # Statement: verify no other driver has the same first AND last name;
        # if it exists, report it and cancel this insertion.
        if team_queries.driver_name_exists(given_name, family_name):
            errors.append(
                f"Linha {line_no}: piloto '{given_name} {family_name}' já existe — inserção cancelada."
            )
            continue

        try:
            team_queries.insert_driver_from_file(
                driver_ref, given_name, family_name, date_of_birth or None, country_id
            )
            inserted.append(f"{given_name} {family_name} ({driver_ref})")
        except psycopg2.errors.RaiseException as e:
            # Trigger cancelled the insert (duplicate generated login).
            errors.append(f"Linha {line_no}: {e.diag.message_primary}")
        except psycopg2.errors.UniqueViolation:
            errors.append(f"Linha {line_no}: driver_ref '{driver_ref}' já existe.")
        except (psycopg2.errors.InvalidDatetimeFormat, psycopg2.errors.DatetimeFieldOverflow):
            errors.append(f"Linha {line_no}: data de nascimento inválida ('{date_of_birth}').")
        except ValueError as e:
            errors.append(f"Linha {line_no}: {e}")

    return {"inserted": inserted, "errors": errors}


@router.get("/reports/4")
def report4(user: dict = team_user):
    return team_queries.report4_driver_wins(user["original_id"])


@router.get("/reports/5")
def report5(user: dict = team_user):
    return team_queries.report5_status_counts(user["original_id"])
