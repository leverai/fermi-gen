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
    base_url: str = 'https://api.fermi.app'  # Base URL for constructing invite links
    web_base_url: str = (
        'https://guesstimate.leverai.tech'  # Base URL for web app invite links
    )

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


settings = Settings()
