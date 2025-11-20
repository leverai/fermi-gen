"""Write-only lifecycle mutations for game documents.

This module is responsible for all state transitions and lifecycle-related
Firestore writes. It does not perform reads and raises domain-specific
exceptions instead of HTTP-aware ones.
"""

import uuid
from typing import TYPE_CHECKING, cast

from google.cloud import firestore

from app.schemas.game import GameDocLifecycle, GameState
from app.services.game.errors import StateConflictError

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import (
        AsyncCollectionReference,
        AsyncDocumentReference,
    )

    from app.services.game.utils import Writeable


class GameLifecycleWriter:
    """Writer for game lifecycle operations."""

    async def create_game(
        self,
        games_ref: 'AsyncCollectionReference',
        writer: 'Writeable',
    ) -> 'AsyncDocumentReference':
        """Create a new game document and return its reference."""
        game_id = str(uuid.uuid4())
        game_ref = games_ref.document(game_id)

        game_data = GameDocLifecycle(
            id=game_id,
            created_at=firestore.SERVER_TIMESTAMP,
            state=GameState.LOBBY_NOT_READY,
        )
        writer.set(game_ref, cast(dict, game_data))

        return game_ref

    def set_ready(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
    ) -> None:
        """Set the game state to ready."""
        writer.update(game_ref, {'state': GameState.LOBBY_READY})

    def start_game(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        state: GameState,
        n_questions: int,
    ) -> None:
        """Start a game. Set started_at and progress.

        Raises:
            StateConflictError: If the current state is not ``LOBBY_READY``.

        """
        if state != GameState.LOBBY_READY:
            raise StateConflictError('Game is not ready')

        state = GameState.QUESTION_N if n_questions > 1 else GameState.QUESTION_LAST
        writer.update(
            game_ref,
            {'started_at': firestore.SERVER_TIMESTAMP, 'state': state},
        )

    def end_game(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        current_state: GameState,
    ) -> bool:
        """End a game and return whether the game had started.

        Raises:
            StateConflictError: If the game is already finished.

        """
        if current_state >= GameState.GAME_FINISHED:
            raise StateConflictError('Game is already finished')

        state = (
            GameState.GAME_FINISHED
            if current_state == GameState.QUESTION_LAST_FINISHED
            else GameState.GAME_ABORTED
        )

        writer.update(
            game_ref,
            {'ended_at': firestore.SERVER_TIMESTAMP, 'state': state},
        )

        return current_state >= GameState.QUESTION_N

    def next_question(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        state: GameState,
        question_order: int,
        n_questions: int,
    ) -> int:
        """Advance to the next question and return its number (0-based).

        Raises:
            StateConflictError: If the current question has not been
                answered by all players (state is not ``QUESTION_N_FINISHED``).

        """
        if state != GameState.QUESTION_N_FINISHED:
            raise StateConflictError(
                'Current question has not been answered by all players',
            )

        next_question_number = question_order + 1
        next_state = (
            GameState.QUESTION_N
            if next_question_number < n_questions
            else GameState.QUESTION_LAST
        )

        writer.update(game_ref, {'state': next_state})

        return next_question_number

    def join_game(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        state: GameState,
    ) -> None:
        """Join a game by transitioning state back to not-ready in the lobby.

        Raises:
            StateConflictError: If attempting to join outside of the lobby
                (state greater than ``LOBBY_READY``).

        """
        if state > GameState.LOBBY_READY:
            raise StateConflictError('Cannot join a game outside of lobby')

        writer.update(game_ref, {'state': GameState.LOBBY_NOT_READY})

    def finish_question(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        state: GameState,
    ) -> GameState:
        """Finish the current question and return the next state.

        Raises:
            StateConflictError: If there is no question in progress
                (state not in ``{QUESTION_N, QUESTION_LAST}``).

        """
        if state not in (GameState.QUESTION_N, GameState.QUESTION_LAST):
            raise StateConflictError('No question in progress')

        next_state = (
            GameState.QUESTION_N_FINISHED
            if state == GameState.QUESTION_N
            else GameState.QUESTION_LAST_FINISHED
        )

        writer.update(game_ref, {'state': next_state})

        return next_state
