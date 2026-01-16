"""Configuration for the Fermi ETL Pipeline."""

from typing import Literal

from dotenv import load_dotenv
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class ETLConfig(BaseSettings):
    """Configuration settings for the ETL pipeline.

    Merges configuration from seed, ask, and answer pipelines.
    Environment variables must be provided (no defaults for required fields).
    """

    model_config = SettingsConfigDict(extra='ignore', env_file='.env')

    # Database
    database_url: str = Field(
        default='postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/fermi-db',
        description='PostgreSQL database URL',
    )

    # API Keys
    openai_api_key: str = Field(..., description='OpenAI API key')
    serp_api_key: str = Field(..., description='SerpAPI key')

    # Gpt answering parameters
    gpt_answer_models: tuple[
        (Literal['gpt-5.1'], Literal['gpt-5-mini'], Literal['gpt-5-nano'])
    ] = Field(
        default=('gpt-5.1', 'gpt-5-mini', 'gpt-5-nano'),
        description='LLM models for question answering',
    )

    # Similarity thresholds
    seed_similarity_threshold: float = Field(
        default=0.1,
        description='Cosine distance threshold for seed uniqueness',
    )
    question_similarity_threshold: float = Field(
        default=0.15,
        description='Cosine distance threshold for question uniqueness',
    )


def get_config() -> ETLConfig:
    """Get ETL pipeline configuration from environment variables.

    Note: Pydantic-settings automatically loads from the env_file specified
    in the Config class. If you need to use a different env file (e.g., for tests),
    load it explicitly before calling this function using load_dotenv().
    """
    load_dotenv(override=False)
    return ETLConfig()  # type: ignore
