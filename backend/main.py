"""FastAPI application entry point.

Run with:  uvicorn main:app --reload --port 8000  (from the backend/ folder)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import admin, auth, driver, team

app = FastAPI(title="F1 FIA Database — SCC-241 Final Project")

# The frontend dev server (Vite) runs on another port, so CORS is needed.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173", "http://127.0.0.1:5173",
        "http://localhost:5174", "http://127.0.0.1:5174",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(team.router)
app.include_router(driver.router)


@app.get("/api/health")
def health():
    return {"status": "ok"}
