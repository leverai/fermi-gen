"""Configuration for the Fermi ETL Pipeline."""

from pydantic import Field
from pydantic_settings import BaseSettings


class ETLConfig(BaseSettings):
    """Configuration settings for the ETL pipeline.

    Merges configuration from seed, ask, and answer pipelines.
    Environment variables must be provided (no defaults for required fields).
    """

    # Database
    database_url: str = Field(
        default='postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db',
        description='PostgreSQL database URL',
    )

    # API Keys
    openai_api_key: str = Field(..., description='OpenAI API key')
    serp_api_key: str = Field(..., description='SerpAPI key')

    # Similarity thresholds
    seed_similarity_threshold: float = Field(
        default=0.1,
        description='Cosine distance threshold for seed uniqueness',
    )
    question_similarity_threshold: float = Field(
        default=0.15,
        description='Cosine distance threshold for question uniqueness',
    )

    class Config:
        """Pydantic config.

        The env_file is set to '.env' by default, but can be overridden
        by loading a different env file before instantiating this class
        (e.g., in test fixtures or main.py).
        """

        env_file = '.env'
        extra = 'ignore'


def get_config() -> ETLConfig:
    """Get ETL pipeline configuration from environment variables.

    Note: Pydantic-settings automatically loads from the env_file specified
    in the Config class. If you need to use a different env file (e.g., for tests),
    load it explicitly before calling this function using load_dotenv().
    """
    return ETLConfig()  # type: ignore
