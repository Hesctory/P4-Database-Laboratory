# Architecture & Design Decisions

## Project: Formula 1 FIA Database Application
**Course:** SCC-241 – Database Laboratory — USP São Carlos  
**Deadline:** June 22, 2026

---

## 1. Technology Stack

### Frontend
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **Component Library:** shadcn/ui
- **Rationale:** shadcn/ui provides accessible, unstyled-by-default components that integrate cleanly with Tailwind. TypeScript enforces type safety across API contracts, reducing integration bugs with the backend.

### Backend
- **Language:** Python
- **Framework:** FastAPI
- **DB Driver:** psycopg2 (raw SQL — no ORM)
- **Rationale:** FastAPI provides automatic OpenAPI docs, native async support, and Pydantic-based request/response validation without hiding the SQL that the project requires to be explicit and evaluable.

### Database
- **DBMS:** PostgreSQL
- **Connection:** psycopg2 connecting to the existing `T1 work` database on `localhost:5432`

---

## 2. Frontend Layer Structure

```
frontend/
├── types/        # TypeScript interfaces and enums (e.g., User, Race, Driver, Team)
├── utils/        # Pure helper functions (date formatting, distance calculation, etc.)
├── services/     # API client functions — one file per backend resource
│   ├── auth.ts
│   ├── drivers.ts
│   ├── teams.ts
│   └── reports.ts
└── components/   # Presentation layer
    ├── views/    # Full page screens (LoginView, DashboardView, ReportsView)
    └── ui/       # Reusable UI primitives (tables, forms, modals)
```

- `types/` defines the shape of all data exchanged with the backend. No inline type definitions in components.
- `utils/` contains no side effects and no API calls.
- `services/` is the only layer allowed to call `fetch`/`axios`. It maps raw API responses to typed objects defined in `types/`.
- `components/` never calls the API directly; it calls `services/` functions.

---

## 3. Backend Layer Structure

```
backend/
├── main.py           # FastAPI app instantiation, router registration, CORS
├── db.py             # Database connection pool (psycopg2), get_connection() helper
├── routers/          # HTTP routing only — no SQL here
│   ├── auth.py       # POST /login, POST /logout
│   ├── admin.py      # Admin-only endpoints
│   ├── team.py       # Team-scoped endpoints
│   └── driver.py     # Driver-scoped endpoints
└── queries/          # All SQL lives here — one file per domain
    ├── auth_queries.py
    ├── admin_queries.py
    ├── team_queries.py
    └── driver_queries.py
```

- **Routers** handle HTTP concerns only: parsing request bodies, calling query functions, returning JSON responses.
- **Queries** contain raw SQL strings executed via psycopg2. Each function receives typed Python parameters and returns typed Python data. No SQL is written outside this layer.
- This separation makes the SQL explicit and reviewable, satisfying the project requirement that SQL commands be visible in the code.

---

## 4. Authentication & User Management

- Authentication is done via the `USERS` table, not PostgreSQL roles.
- Passwords are stored hashed using `pgcrypto`'s `crypt()` with `gen_salt('bf')` (bcrypt).
- Session management: JWT token issued on login, sent as a Bearer token on subsequent requests. The backend validates the token and extracts `userid`, `type`, and `original_id` on each request.
- The `USERS_LOG` table records every LOGIN and LOGOUT event with `userid`, action type, and timestamp.

### User Types and Access Control
| Type   | Login Pattern         | Password      | Scope                              |
|--------|-----------------------|---------------|------------------------------------|
| Admin  | `admin`               | `admin`       | Full access                        |
| Team   | `<constructor_ref>_c` | `constructor_ref` | Own team + associated drivers  |
| Driver | `<driver_ref>_d`      | `driver_ref`  | Own performance data only          |

---

## 5. Database Objects

All SQL that modifies or extends the database lives under `backend/sql/`, organized by concern. These scripts are applied on top of the existing `DB_backup.sql` and are the single source of truth for every database object created by this project.

```
backend/sql/
├── 01_users.sql        # CREATE TABLE USERS, USERS_LOG; populate from existing DRIVERS/CONSTRUCTORS
├── 02_triggers.sql     # Triggers keeping USERS in sync with DRIVERS and CONSTRUCTORS
├── 03_functions.sql    # Stored functions for dashboard and report data
├── 04_views.sql        # Views shared across reports
└── 05_indexes.sql      # Indexes; each one preceded by a comment justifying it
```

Scripts are numbered so they can be applied in order. No DDL is scattered across the Python code.

### Triggers (`02_triggers.sql`)
- `trg_after_insert_driver`: after INSERT on `DRIVERS`, inserts the corresponding row in `USERS`. If the login already exists, raises an exception and cancels the insert.
- `trg_after_update_driver`: after UPDATE on `DRIVERS` (name/ref change), updates the corresponding `USERS` row.
- Equivalent triggers for `CONSTRUCTORS`.

### Views (`04_views.sql`)
- Defined per report where the same join/aggregation is reused across user types.

### Stored Functions/Procedures (`03_functions.sql`)
- **Team dashboard:** `fn_team_wins(constructor_id)`, `fn_team_driver_count(constructor_id)`, `fn_team_active_years(constructor_id)`
- **Driver dashboard:** `fn_driver_active_years(driver_id)`, `fn_driver_yearly_circuit_stats(driver_id)`
- **Reports:** separate functions for Reports 4–7 receiving the team or driver id as parameter.

### Indexes (`05_indexes.sql`)
- Each `CREATE INDEX` statement is preceded by a comment explaining which query, filter, or join it targets, as required by the project statement.

---

## 6. Screen Flow

```
LoginView  →  DashboardView  →  ReportsView
                   ↑                  |
                   └──────────────────┘  (back after closing a report)
```

- Three screens, one React Router route each: `/login`, `/dashboard`, `/reports`.
- After closing a report result, the UI returns to `/reports` (not `/dashboard`).
- The dashboard varies by user type; the reports screen shows only the reports available to the logged-in type.

---

## 7. Key Constraints from Project Requirements

- No ORM: all SQL must be explicit and written by hand in the `queries/` layer.
- Column names shown to users must be in **Portuguese** in all tables, dashboards, and reports.
- Passwords never stored in plain text.
- All database concepts used (procedures, triggers, views, indexes, joins, aggregations, access control) must be commented in the source with a brief justification.
