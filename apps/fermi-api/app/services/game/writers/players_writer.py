"""Write-only player mutations for game documents.

This module is responsible for adding, removing, and updating player-related
data in Firestore. It does not perform reads and raises domain-specific
exceptions instead of HTTP-aware ones.
"""

from collections.abc import Iterable
from typing import TYPE_CHECKING, cast

from google.cloud import firestore

from app.schemas.game import GameDocPlayers, GamePlayer, GameState
from app.services.game.errors import (
    NotFoundError,
    StateConflictError,
    ValidationError,
)

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1.async_document import AsyncDocumentReference

    from app.services.game.utils import Writeable


MAX_PLAYERS = 8


class GamePlayersWriter:
    """Writer for game players operations."""

    def _user_to_player(self, user: 'User', *, is_host: bool) -> GamePlayer:
        """Convert user to player info."""
        return GamePlayer(
            player_id=user.firebase_uid,
            name=user.display_name,
            picture=user.picture,
            score=0,
            rank=0,
            is_host=is_host,
            is_active=True,
        )

    def set_players(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        host_id: str,
        users: Iterable['User'],
    ) -> None:
        """Set game players, host, and full flag.

        Raises:
            ValidationError: If ``host_id`` is not among provided users or
                if the number of players exceeds the maximum allowed.

        """
        players = {
            user.firebase_uid: self._user_to_player(
                user,
                is_host=user.firebase_uid == host_id,
            )
            for user in users
        }

        # Validate setup
        if host_id not in players:
            raise ValidationError('Host not in players')

        n_players = len(players)
        if n_players > MAX_PLAYERS:
            raise ValidationError('Too many players')

        game_data = GameDocPlayers(
            host=host_id,
            players=players,
            full=n_players == MAX_PLAYERS,
        )
        writer.update(game_ref, cast(dict, game_data))

    def add_player(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        players: dict[str, GamePlayer],
        user: 'User',
    ) -> list[str]:
        """Add a player to the game and return user_uids.

        Raises:
            StateConflictError: If the player already joined the game.

        """
        if user.firebase_uid in players:
            raise StateConflictError('Player already joined the game')

        writer.update(
            game_ref,
            {
                f'players.{user.firebase_uid}': self._user_to_player(
                    user,
                    is_host=False,
                ),
                'full': (len(players) + 1) == MAX_PLAYERS,
            },
        )

        return [*list(players), user.firebase_uid]

    def get_active_player_ids(self, players: dict[str, GamePlayer]) -> list[str]:
        """Get active player IDs."""
        return [pid for pid, pinfo in players.items() if pinfo['is_active']]

    def remove_player(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        players: dict[str, GamePlayer],
        remove_id: str,
        state: GameState,
        *,
        is_host: bool,
    ) -> list[str]:
        """Remove a player from the game and return active player IDs.

        Raises:
            NotFoundError: If the player is not found among active players.

        """
        active_player_ids = self.get_active_player_ids(players)
        if remove_id not in active_player_ids:
            raise NotFoundError('Player not found')

        if state <= GameState.LOBBY_READY:
            writer.update(game_ref, {f'players.{remove_id}': firestore.DELETE_FIELD})
        else:
            writer.update(game_ref, {f'players.{remove_id}.is_active': False})
        active_player_ids.remove(remove_id)

        writer.update(game_ref, {'full': False})

        if not active_player_ids:
            return []

        if is_host:
            writer.update(game_ref, {'host': active_player_ids[0]})
        return active_player_ids

    def update_scores_and_ranks(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        players: dict[str, GamePlayer],
        question_scores: dict[str, float],
    ) -> None:
        """Update players' cumulative scores and ranks based on question results.

        Args:
            game_ref: Reference to the game document.
            writer: Transaction or batch to write with.
            players: Current players dict from the game document.
            question_scores: Map of player_id to score earned for the current question.

        """
        # Calculate new cumulative scores for active players
        new_scores: dict[str, float] = {}
        for player_id, player in players.items():
            if not player['is_active']:
                continue
            question_score = question_scores.get(player_id, 0.0)
            new_scores[player_id] = player['score'] + question_score

        # Calculate ranks (sorted by score descending, rank 0 is 1st place)
        sorted_players = sorted(new_scores.items(), key=lambda x: x[1], reverse=True)
        ranks: dict[str, int] = {
            player_id: rank for rank, (player_id, _) in enumerate(sorted_players)
        }

        # Build update dict for all players
        updates: dict[str, float | int] = {}
        for player_id in new_scores:
            updates[f'players.{player_id}.score'] = new_scores[player_id]
            updates[f'players.{player_id}.rank'] = ranks[player_id]

        writer.update(game_ref, updates)
