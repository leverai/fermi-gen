"""Write-only question and answer document mutations for games.

This module handles creating, clearing, and revealing question/answer documents
in Firestore. It does not perform reads and raises domain-specific exceptions
instead of HTTP-aware ones.
"""

from collections.abc import Iterable
from typing import TYPE_CHECKING, cast

from fermi_db.schemas import QuestionDifficulty

from app.schemas.endpoints import RequestCategory

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import (
        AsyncCollectionReference,
        AsyncDocumentReference,
    )

    from app.schemas.game import AnswerDoc, QuestionDoc
    from app.services.game.utils import Writeable


class GameQuestionsWriter:
    """Writer for game questions operations."""

    def set_questions(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        questions_docs: Iterable['QuestionDoc'],
        answers_docs: Iterable['AnswerDoc'],
        request_category: RequestCategory | None,
        game_difficulty: QuestionDifficulty | None,
    ) -> list[str]:
        """Create questions and answers documents, and set question_uids."""
        questions_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('questions'),
        )
        answers_ref = cast('AsyncCollectionReference', game_ref.collection('answers'))
        question_uids = []
        for question_doc, answer_doc in zip(questions_docs, answers_docs, strict=True):
            question_uid = question_doc['question_uid']
            writer.set(
                questions_ref.document(question_uid),
                cast(dict, question_doc),
            )
            writer.set(
                answers_ref.document(question_uid),
                cast(dict, answer_doc),
            )
            question_uids.append(question_uid)

        writer.update(
            game_ref,
            {
                'question_uids': question_uids,
                'category': request_category,
                'difficulty': game_difficulty,
                'n_questions': len(question_uids),
            },
        )
        return question_uids

    def reveal_question(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        question_uid: str,
        question_order: int,
        timeout_seconds: int | None,
    ) -> None:
        """Reveal the question and update game doc."""
        writer.update(
            game_ref.collection('questions').document(question_uid),
            {'revealed': True},
        )

        writer.update(
            game_ref,
            {
                'question_uid': question_uid,
                'question_order': question_order,
                'question_duration_s': timeout_seconds,
            },
        )

    def clear_questions(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        question_uids: list[str],
    ) -> None:
        """Clear questions and answers sub-collections for the provided UIDs."""
        questions_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('questions'),
        )
        answers_ref = cast('AsyncCollectionReference', game_ref.collection('answers'))
        for question_uid in question_uids:
            writer.delete(questions_ref.document(question_uid))
            writer.delete(answers_ref.document(question_uid))

        writer.update(game_ref, {'question_uids': []})
