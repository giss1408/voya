# Voya Booking API

FastAPI backend for the core booking engine (routes, trips, seat holds,
bookings, payments, signed tickets) plus a static Fleet dashboard for
operators.

## Run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8008
```

- API docs: http://localhost:8008/docs
- Fleet dashboard: http://localhost:8008/dashboard/

Defaults to a local SQLite file (`voya.db`). Point `VOYA_DATABASE_URL` at
Postgres for anything beyond local dev, e.g.:

```bash
export VOYA_DATABASE_URL=postgresql://user:pass@localhost:5432/voya
```

## What's implemented

- Operator + vehicle + route + trip management
- Seat holds with a 90s expiry (configurable via `VOYA_SEAT_HOLD_SECONDS`)
- Booking creation with mobile-money/card (pending → confirm) or
  cash-on-boarding (confirms immediately) payment paths
- HMAC-signed, offline-verifiable boarding tickets (QR payload + 6-digit
  fallback code), independent of a live DB lookup
- Trip manifest endpoint for the Fleet dashboard

## Not yet implemented

- Real PSP integration (mobile money / card) — `confirm-payment` is a stub
  a PSP webhook would call
- USSD/agent surface
- Auth/RBAC on the Fleet dashboard (currently open — add before any
  non-local deployment)
- Operator KYC workflow (status field exists, no verification flow yet)

## Deploying to Render

`render.yaml` (repo root) defines two environments:

| Branch | Service | Database | `VOYA_ENV` |
|--------|---------|----------|------------|
| `integration` | `voya-api-integration` | `voya-db-integration` | `integration` |
| `prod` | `voya-api-prod` | `voya-db-prod` | `production` |

Flow: feature work on `master` -> merge to `integration` (auto-deploys, test) -> merge `integration` into `prod` (auto-deploys).

Setup: Render Dashboard > New > Blueprint > this repo. Then fill the
`sync: false` variables (`VOYA_ADMIN_PHONE`, `VOYA_ADMIN_PASSWORD` for prod,
`VOYA_CORS_ORIGINS` for prod). Signing keys are generated per environment and
must never be shared between them (tickets signed in one are invalid in the other).

In `integration` and `production` the app refuses to start with dev default
secrets, SQLite, or (production) wildcard CORS. Point the Flutter apps at a
deployment with `--dart-define=VOYA_API_BASE=https://<service>.onrender.com`.

Known gaps before real traffic: tables are created with `create_all` (no
migrations; add Alembic), and the free integration database expires after 30 days.
