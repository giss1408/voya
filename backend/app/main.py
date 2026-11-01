from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.db import Base, SessionLocal, engine
from app.models import models  # noqa: F401  (registers models with Base)
from app.routers import agent, auth, bookings, manifest, operators, trips
from app.services.bootstrap import ensure_platform_admin

Base.metadata.create_all(bind=engine)

with SessionLocal() as _db:
    ensure_platform_admin(_db)

app = FastAPI(title="Voya Booking API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(operators.router)
app.include_router(trips.router)
app.include_router(bookings.router)
app.include_router(manifest.router)
app.include_router(agent.router)

app.mount("/dashboard", StaticFiles(directory="app/static", html=True), name="dashboard")
app.mount("/app", StaticFiles(directory="app/static_rider", html=True), name="rider-app")


@app.get("/health")
def health():
    return {"status": "ok"}
