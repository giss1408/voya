from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./voya.db"
    ticket_signing_key: str = "dev-only-change-me-in-production"
    seat_hold_seconds: int = 90
    admin_phone: str = "+000000000"
    admin_password: str = "dev-only-change-me"

    class Config:
        env_prefix = "VOYA_"


settings = Settings()
