from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings


_DEV_SIGNING_KEY = "dev-only-change-me-in-production"
_DEV_ADMIN_PASSWORD = "dev-only-change-me"


class Settings(BaseSettings):
    # development | integration | production
    env: str = "development"
    database_url: str = "sqlite:///./voya.db"
    ticket_signing_key: str = _DEV_SIGNING_KEY
    seat_hold_seconds: int = 90
    admin_phone: str = "+000000000"
    admin_password: str = _DEV_ADMIN_PASSWORD
    # Comma-separated origins allowed by CORS; "*" for development only.
    cors_origins: str = "*"

    @field_validator("database_url")
    @classmethod
    def _normalize_database_url(cls, v: str) -> str:
        # Render (and Heroku) hand out postgres://, which SQLAlchemy 2 rejects.
        if v.startswith("postgres://"):
            return "postgresql://" + v[len("postgres://"):]
        return v

    @model_validator(mode="after")
    def _require_real_secrets(self):
        if self.env in ("integration", "production"):
            if self.ticket_signing_key == _DEV_SIGNING_KEY:
                raise ValueError("VOYA_TICKET_SIGNING_KEY must be set")
            if self.admin_password == _DEV_ADMIN_PASSWORD:
                raise ValueError("VOYA_ADMIN_PASSWORD must be set")
            if self.database_url.startswith("sqlite"):
                raise ValueError("VOYA_DATABASE_URL must point to Postgres")
        if self.env == "production" and self.cors_origins.strip() == "*":
            raise ValueError("VOYA_CORS_ORIGINS must list explicit origins")
        return self

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    class Config:
        env_prefix = "VOYA_"


settings = Settings()
