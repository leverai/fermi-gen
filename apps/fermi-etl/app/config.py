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

    # Pipeline parameters
    question_generation_model: str = Field(
        default='gpt-5-mini',
        description='LLM model for question generation',
    )
    question_generation_model_provider: str = Field(
        default='openai',
        description='LLM model provider for question generation (e.g., openai, ollama)',
    )

    # Answer generation parameters
    location_model: str = Field(
        default='gpt-5-nano',
        description='Model for location selection',
    )
    extraction_model: str = Field(
        default='gpt-5-nano',
        description='Model for answer extraction',
    )
    model_provider: str = Field(
        default='openai',
        description='Model provider for answer generation',
    )
    confidence_threshold: float = Field(
        default=0.8,
        description='Minimum confidence threshold for answers',
    )
    category_model: str = Field(
        default='gpt-5-nano',
        description='Model for category enrichment',
    )
    category_model_provider: str = Field(
        default='openai',
        description='Model provider for category enrichment',
    )
    difficulty_model: str = Field(
        default='gpt-5-nano',
        description='Model for difficulty enrichment',
    )
    difficulty_model_provider: str = Field(
        default='openai',
        description='Model provider for difficulty enrichment',
    )

    # LLM answering parameters
    llm_answer_models: list[str] = Field(
        default=['gpt-5.1', 'gpt-5-mini', 'gpt-5-nano'],
        description='LLM models for question answering',
    )
    llm_answer_model_provider: str = Field(
        default='openai',
        description='Provider for LLM answer models',
    )

    # Gemini Flash answering parameters (casual/dumb bots)
    gemini_flash_models: list[str] = Field(
        default=[
            'gemini-flash-1',
            'gemini-flash-2',
            'gemini-flash-3',
            'gemini-flash-4',
            'gemini-flash-5',
        ],
        description='Gemini Flash model instances for casual bots',
    )
    gemini_flash_temperature: float = Field(
        default=1.5,
        description='High temperature for varied/casual answers',
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
