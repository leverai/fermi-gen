"""Firestore writer for DeathMatch mode.

Manages the Firestore documents that power real-time DeathMatch state.
Collection layout:
  dm_queue/{player_id}        - matchmaking queue entries
  dm_matches/{match_id}       - match documents (both players listen)
"""

import uuid
from typing import TYPE_CHECKING, Any, cast

from google.cloud import firestore

from app.schemas.deathmatch import POINTS_STAKE, DMPlayer, DMState

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncClient, DocumentSnapshot


QUEUE_COLLECTION = 'dm_queue'
MATCHES_COLLECTION = 'dm_matches'


class DMFirestoreWriter:
    """Manages Firestore documents for DeathMatch mode."""

    def __init__(self, firestore_client: 'AsyncClient') -> None:
        """Initialize with Firestore client."""
        self._fs = firestore_client

    # ---- Queue operations ----

    async def enqueue_player(self, player: DMPlayer) -> None:
        """Add a player to the matchmaking queue."""
        doc_ref = self._fs.collection(QUEUE_COLLECTION).document(player['player_id'])
        await doc_ref.set(
            {
                'player_id': player['player_id'],
                'name': player['name'],
                'picture': player['picture'],
                'points': player['points'],
                'queued_at': firestore.SERVER_TIMESTAMP,
            },
        )

    async def dequeue_player(self, player_id: str) -> None:
        """Remove a player from the queue."""
        doc_ref = self._fs.collection(QUEUE_COLLECTION).document(player_id)
        await doc_ref.delete()

    async def pop_waiting_opponent(self, exclude_player_id: str) -> DMPlayer | None:
        """Atomically find and remove the oldest queued opponent.

        Uses a transaction to prevent two players from matching with
        the same opponent.
        """
        tx = self._fs.transaction()

        @firestore.async_transactional
        async def _pop(transaction: Any) -> DMPlayer | None:
            query = (
                self._fs.collection(QUEUE_COLLECTION).order_by('queued_at').limit(10)
            )
            docs = [doc async for doc in query.stream(transaction=transaction)]
            for doc in docs:
                data = doc.to_dict()
                if data and data['player_id'] != exclude_player_id:
                    transaction.delete(doc.reference)
                    return DMPlayer(
                        player_id=data['player_id'],
                        name=data.get('name'),
                        picture=data.get('picture'),
                        points=data.get('points', 0),
                    )
            return None

        return await _pop(tx)

    # ---- Match operations ----

    async def create_match(
        self,
        player1: DMPlayer,
        player2: DMPlayer | None,
        *,
        question_data: dict[str, Any] | None = None,
    ) -> str:
        """Create a new match document. Returns the match_id."""
        match_id = str(uuid.uuid4())
        doc_ref = self._fs.collection(MATCHES_COLLECTION).document(match_id)

        state = DMState.QUESTION_ACTIVE if player2 else DMState.WAITING_FOR_OPPONENT

        doc: dict[str, Any] = {
            'state': int(state),
            'player1': dict(player1),
            'player2': dict(player2) if player2 else None,
            'question_uid': None,
            'question_text': None,
            'player1_answered': False,
            'player2_answered': False,
            'winner': None,
            'points_transferred': POINTS_STAKE,
            'created_at': firestore.SERVER_TIMESTAMP,
        }

        if question_data:
            doc.update(question_data)

        await doc_ref.set(doc)
        return match_id

    async def set_opponent_and_question(
        self,
        match_id: str,
        player2: DMPlayer,
        question_data: dict[str, Any],
    ) -> None:
        """Assign an opponent and question to a waiting match."""
        doc_ref = self._fs.collection(MATCHES_COLLECTION).document(match_id)
        await doc_ref.update(
            {
                'state': int(DMState.QUESTION_ACTIVE),
                'player2': dict(player2),
                **question_data,
            },
        )

    async def get_match(self, match_id: str) -> dict[str, Any] | None:
        """Read a match document."""
        doc_ref = self._fs.collection(MATCHES_COLLECTION).document(match_id)
        snap = cast('DocumentSnapshot', await doc_ref.get())
        return snap.to_dict()

    async def submit_player_answer(
        self,
        match_id: str,
        player_slot: str,
        answer: dict[str, Any],
        score: float,
    ) -> dict[str, Any]:
        """Record a player's answer. Uses a transaction to handle race conditions.

        Args:
            match_id: The match document ID.
            player_slot: 'player1' or 'player2'.
            answer: The AnswerBare dict.
            score: Computed score.

        Returns:
            Updated match data after the write.

        """
        doc_ref = self._fs.collection(MATCHES_COLLECTION).document(match_id)
        tx = self._fs.transaction()

        @firestore.async_transactional
        async def _submit(transaction: Any) -> dict[str, Any]:
            snap = await doc_ref.get(transaction=transaction)
            data = snap.to_dict() or {}

            answered_key = f'{player_slot}_answered'
            if data.get(answered_key):
                return data

            updates: dict[str, Any] = {
                answered_key: True,
                f'{player_slot}_answer': answer,
                f'{player_slot}_score': score,
            }

            other_slot = 'player2' if player_slot == 'player1' else 'player1'
            other_answered = data.get(f'{other_slot}_answered', False)

            if other_answered:
                other_score = data.get(f'{other_slot}_score', 0.0)
                if score > other_score:
                    winner = data[player_slot]['player_id']
                elif other_score > score:
                    winner = data[other_slot]['player_id']
                else:
                    winner = None  # draw

                updates['winner'] = winner
                updates['state'] = int(DMState.QUESTION_RESOLVED)

            transaction.update(doc_ref, updates)
            data.update(updates)
            return data

        return await _submit(tx)

    async def finish_match(self, match_id: str) -> None:
        """Mark a match as finished."""
        doc_ref = self._fs.collection(MATCHES_COLLECTION).document(match_id)
        await doc_ref.update({'state': int(DMState.MATCH_FINISHED)})

    async def forfeit_match(
        self,
        match_id: str,
        forfeiting_player_id: str,
    ) -> dict[str, Any] | None:
        """Handle a player forfeiting / leaving.

        The opponent wins by default.
        """
        doc_ref = self._fs.collection(MATCHES_COLLECTION).document(match_id)
        tx = self._fs.transaction()

        @firestore.async_transactional
        async def _forfeit(transaction: Any) -> dict[str, Any] | None:
            snap = await doc_ref.get(transaction=transaction)
            data = snap.to_dict()
            if not data:
                return None

            state = DMState(data['state'])
            if state >= DMState.QUESTION_RESOLVED:
                return data

            p1 = data.get('player1') or {}
            p2 = data.get('player2') or {}

            if p1.get('player_id') == forfeiting_player_id:
                winner = p2.get('player_id') if p2 else None
            elif p2.get('player_id') == forfeiting_player_id:
                winner = p1.get('player_id')
            else:
                return data

            transaction.update(
                doc_ref,
                {
                    'state': int(DMState.MATCH_FINISHED),
                    'winner': winner,
                },
            )
            data['state'] = int(DMState.MATCH_FINISHED)
            data['winner'] = winner
            return data

        return await _forfeit(tx)

    async def cleanup_stale_queue_entries(self, max_age_seconds: int = 120) -> int:
        """Remove queue entries older than max_age_seconds."""
        import datetime

        cutoff = datetime.datetime.now(datetime.UTC) - datetime.timedelta(
            seconds=max_age_seconds,
        )
        query = self._fs.collection(QUEUE_COLLECTION).where(
            'queued_at',
            '<',
            cutoff,
        )
        count = 0
        async for doc in query.stream():
            await doc.reference.delete()
            count += 1
        return count
