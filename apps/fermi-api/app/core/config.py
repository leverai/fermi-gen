"""Environment settings for the application."""

import datetime

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment settings."""

    model_config = SettingsConfigDict(
        alias_generator=lambda x: x.upper(),
        case_sensitive=True,
        env_file='.env',
        extra='ignore',
    )

    project_name: str = 'fermi-api'
    api_v1_str: str = '/api/v1'

    # Database
    database_url: str = 'postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db'

    # JWT
    jwt_secret_key: str = 'secret'  # noqa: S105
    jwt_algorithm: str = 'HS256'
    jwt_exp: datetime.timedelta = datetime.timedelta(minutes=30)

    # Emulators - Optional in production, required for local dev
    firestore_emulator_host: str | None = '127.0.0.1:8080'
    firebase_auth_emulator_host: str | None = '127.0.0.1:9099'
    google_cloud_project: str = 'fermi-local'

    # App mode
    use_emulators: bool = True

    # ChottuLink - Invite URL base for deep links
    # For local dev, leave as None to use trampoline endpoints
    # For dev/prod, set to 'https://guesstimate.chottu.link'
    invite_url_base: str | None = None


settings = Settings()
