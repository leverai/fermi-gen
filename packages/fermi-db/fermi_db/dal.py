"""Data Access Layer for the Fermi-Gen database."""

from sqlmodel.ext.asyncio.session import AsyncSession

from .repositories.answer_repository import AnswerRepository
from .repositories.enrichment_repository import EnrichmentRepository
from .repositories.fermi_answer_repository import FermiAnswerRepository
from .repositories.fermi_repository import FermiRepository
from .repositories.llm_answer_repository import LLMAnswerRepository
from .repositories.question_repository import QuestionRepository
from .repositories.question_votes_repository import QuestionVotesRepository
from .repositories.raw_question_repository import RawQuestionRepository
from .repositories.seed_repository import SeedRepository
from .repositories.seeds_usage_repository import SeedsUsageRepository
from .repositories.user_history_repository import UserHistoryRepository


class DatabaseClient:
    """A client for interacting with the Fermi-Gen database."""

    def __init__(self, session: AsyncSession) -> None:
        """Initialize the database client and repositories."""
        self.session = session
        # Question repositories
        self.questions = QuestionRepository(self.session)
        self.users_history = UserHistoryRepository(self.session)
        self.answers = AnswerRepository(self.session)
        self.question_votes = QuestionVotesRepository(self.session)
        self.fermi = FermiRepository(self.session)
        # Pipeline repositories
        self.seeds = SeedRepository(self.session)
        self.raw_questions = RawQuestionRepository(self.session)
        self.seeds_usage = SeedsUsageRepository(self.session)
        self.fermi_answers = FermiAnswerRepository(self.session)
        self.llm_answers = LLMAnswerRepository(self.session)
        self.enrichment = EnrichmentRepository(self.session)
