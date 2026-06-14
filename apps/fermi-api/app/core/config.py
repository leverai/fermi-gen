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
    jwt_max_refresh_age: datetime.timedelta = datetime.timedelta(days=30)

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

    # RevenueCat
    revenuecat_webhook_secret: str = ''

    # Scheduler authentication (shared secret for Cloud Scheduler endpoints)
    # Even with OIDC configured at Cloud Run level, this provides defense-in-depth
    scheduler_secret: str = ''

    # Pro bypass emails - these users bypass Pro gating (treated as Pro)
    pro_bypass_emails: list[str] = ['leverai@leverai.tech', 'testers@leverai.tech']

    # Logging
    log_level: str = 'INFO'
    log_format: str = 'auto'  # 'json', 'text', or 'auto' (auto-detect)

    # Smart search (semantic party-game search). Feature ships dark: only
    # `smart_search_enabled` is exposed to clients (via GameConfigResponse); the
    # rest are server-side dials tuned from telemetry.
    smart_search_enabled: bool = False
    smart_search_pool_size: int = 25
    """Candidate pool size M: nearest kept after the floor, before fairness."""
    smart_search_similarity_floor: float = 0.30
    """Min cosine similarity in [0, 1] (generous start; tune up via telemetry)."""
    smart_search_min_results: int = 6
    """Min matches for a search game; fewer -> 'broaden your search' error."""


settings = Settings()
