"""Read-focused repository for Game data.

Centralizes field masks and Firestore read operations for games. Methods
accept an optional ``tx`` parameter to support transactional reads.
"""

import asyncio
from collections.abc import Iterable
from typing import TYPE_CHECKING, Any, cast

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from app.schemas.endpoints import QuestionRoundSettings, QuestionSettings
from app.schemas.game import AnswerDoc, GameState, PlayersResultsDoc

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import (
        AsyncClient,
        AsyncCollectionReference,
        AsyncDocumentReference,
        AsyncTransaction,
        DocumentSnapshot,
    )


class GameRepository:
    """Narrow, typed read APIs for game documents and subcollections."""

    def __init__(self, client: 'AsyncClient') -> None:
        """Initialize the repository with a Firestore client."""
        self._client = client

    async def get_game_fields(
        self,
        game_ref: 'AsyncDocumentReference',
        *,
        fields: list[str] | None = None,
        tx: 'AsyncTransaction | None' = None,
    ) -> dict[str, Any]:
        """Return selected fields from a game document.

        Use this generic accessor to minimize duplication across specific
        field-getter methods.
        """
        snapshot = cast(
            'DocumentSnapshot',
            await game_ref.get(field_paths=fields, transaction=tx),
        )
        return snapshot.to_dict() or {}

    async def get_correct_answer(
        self,
        game_ref: 'AsyncDocumentReference',
        *,
        question_uid: str,
        tx: 'AsyncTransaction | None' = None,
    ) -> 'AnswerDoc':
        """Return the correct answer document for a question."""
        answers_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('answers'),
        )
        snapshot = cast(
            'DocumentSnapshot',
            await answers_ref.document(question_uid).get(
                field_paths=None,
                transaction=tx,
            ),
        )
        return cast('AnswerDoc', snapshot.to_dict() or {})

    async def get_questions_settings(
        self,
        game_ref: 'AsyncDocumentReference',
        *,
        question_uids: Iterable[str],
        tx: 'AsyncTransaction | None' = None,
    ) -> dict[str, QuestionSettings]:
        """Return settings for each question UID."""
        questions_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('questions'),
        )

        fields = ['category', 'difficulty']
        tasks = [
            questions_ref.document(qid).get(
                field_paths=fields,
                transaction=tx,
            )
            for qid in question_uids
        ]
        snapshots = await asyncio.gather(*tasks)

        return {
            qid: QuestionSettings.model_validate(
                cast('DocumentSnapshot', snapshot).to_dict() or {},
            )
            for qid, snapshot in zip(question_uids, snapshots, strict=True)
        }

    async def get_players_results_docs(
        self,
        game_ref: 'AsyncDocumentReference',
        *,
        question_uids: Iterable[str],
        tx: 'AsyncTransaction | None' = None,
    ) -> list['PlayersResultsDoc']:
        """Return players' results documents for provided question UIDs."""
        players_results_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('players_results'),
        )
        docs: list[PlayersResultsDoc] = []
        for qid in question_uids:
            snap = cast(
                'DocumentSnapshot',
                await players_results_ref.document(qid).get(
                    field_paths=None,
                    transaction=tx,
                ),
            )
            docs.append(cast('PlayersResultsDoc', snap.to_dict() or {}))
        return docs

    async def get_players_results_doc(
        self,
        game_ref: 'AsyncDocumentReference',
        *,
        question_uid: str,
        tx: 'AsyncTransaction | None' = None,
    ) -> 'PlayersResultsDoc':
        """Return players' results document for a single question UID."""
        players_results_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('players_results'),
        )
        snap = cast(
            'DocumentSnapshot',
            await players_results_ref.document(question_uid).get(
                field_paths=None,
                transaction=tx,
            ),
        )
        return cast('PlayersResultsDoc', snap.to_dict() or {})

    async def find_public_available_game(
        self,
        games_ref: 'AsyncCollectionReference',
        *,
        round_settings: QuestionRoundSettings,
        tx: 'AsyncTransaction | None' = None,
    ) -> 'DocumentSnapshot | None':
        """Return one public, non-full game at or before lobby-ready matching
        filters.
        """
        query = (
            games_ref.where(filter=FieldFilter('private', '==', value=False))
            .where(filter=FieldFilter('full', '==', value=False))
            .where(
                filter=FieldFilter('state', '<=', value=GameState.LOBBY_READY),
            )
        )

        if round_settings.category is not None:
            query = query.where(
                filter=FieldFilter('category', '==', value=round_settings.category),
            )
        if round_settings.difficulty is not None:
            query = query.where(
                filter=FieldFilter('difficulty', '==', value=round_settings.difficulty),
            )

        query = query.order_by(
            field_path='created_at',
            direction=firestore.Query.DESCENDING,
        ).limit(
            1,
        )

        games = await query.get(transaction=tx)
        if not games:
            return None
        return games.pop()
