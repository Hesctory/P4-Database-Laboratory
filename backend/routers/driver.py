"""Driver endpoints: dashboard and Reports 6–7.

Drivers are read-only users (statement, section 3): no mutating endpoint
exists here, and every query is bound to the logged-in driver's id.
"""

from fastapi import APIRouter, Depends

from queries import driver_queries
from security import require_type

router = APIRouter(prefix="/api/driver", tags=["driver"])

driver_user = Depends(require_type("Driver"))


@router.get("/dashboard")
def dashboard(user: dict = driver_user):
    return driver_queries.get_dashboard(user["original_id"])


@router.get("/reports/6")
def report6(user: dict = driver_user):
    return driver_queries.report6_points_by_year(user["original_id"])


@router.get("/reports/7")
def report7(user: dict = driver_user):
    return driver_queries.report7_status_counts(user["original_id"])
