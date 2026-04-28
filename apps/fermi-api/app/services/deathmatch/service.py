"""DeathMatch game mode service.

Two players are matched randomly. They both answer the same Fermi question.
The player with the higher score wins and takes POINTS_STAKE (50) points
from the loser. The loser is replaced by the next player in the queue
(or a bot if no human players are waiting).
"""

import logging
import random
import uuid
from typing import TYPE_CHECKING, Any

from fastapi import HTTPException, status
from fermi_core.units import get_unit_family
from fermi_db.models import AnswerEvent
from fermi_db.schemas import AnswerBare, GameMode, QuestionCategory, QuestionDifficulty

from app.schemas.deathmatch import (
    POINTS_STAKE,
    DMAnswerResponse,
    DMLeaveResponse,
    DMMatchStatusResponse,
    DMPlayer,
    DMQuestionData,
    DMQueueResponse,
    DMResultResponse,
    DMState,
)
from app.services.deathmatch.firestore_writer import DMFirestoreWriter
from app.services.game.bots import BOTS, get_bot_answer, is_bot
from app.services.scoring import ScoringService

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.models import Fermi
    from google.cloud.firestore_v1 import AsyncClient


class DeathMatchService:
    """Service for DeathMatch game mode."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize with database client."""
        self._db = db_client
        self._scoring = ScoringService()

    async def queue(
        self,
        current_user_firebase_uid: str,
        current_user_name: str | None,
        current_user_picture: str | None,
        firestore_client: 'AsyncClient',
    ) -> DMQueueResponse:
        """Enter the matchmaking queue.

        1. Check if the player is already in a waiting match.
        2. Try to find an opponent in the queue.
        3. If found: create a match with both players + question.
        4. If not found: create a waiting match and enqueue.
        """
        writer = DMFirestoreWriter(firestore_client)
        user_points = await self._db.users.get_points(current_user_firebase_uid)

        me = DMPlayer(
            player_id=current_user_firebase_uid,
            name=current_user_name,
            picture=current_user_picture,
            points=user_points,
        )

        # Try to find an opponent already in the queue
        opponent = await writer.pop_waiting_opponent(
            exclude_player_id=current_user_firebase_uid,
        )

        if opponent:
            # Found a human opponent - create a match with a question
            question, q_data = await self._fetch_question_data(
                user_ids=[me['player_id'], opponent['player_id']],
            )
            match_id = await writer.create_match(me, opponent, question_data=q_data)
            logger.info(
                'DM: matched %s vs %s → match %s',
                me['player_id'],
                opponent['player_id'],
                match_id,
            )
            return DMQueueResponse(match_id=match_id, status='matched')

        # No opponent available - create a waiting match
        match_id = await writer.create_match(me, None)
        await writer.enqueue_player(me)
        logger.info('DM: %s queued → match %s (waiting)', me['player_id'], match_id)
        return DMQueueResponse(match_id=match_id, status='waiting')

    async def check_and_match(
        self,
        match_id: str,
        current_user_firebase_uid: str,
        firestore_client: 'AsyncClient',
    ) -> DMMatchStatusResponse:
        """Poll match status; if still waiting, try to match with a bot."""
        writer = DMFirestoreWriter(firestore_client)
        match = await writer.get_match(match_id)
        if not match:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Match not found',
            )

        state = DMState(match['state'])

        # Already matched or beyond
        if state >= DMState.QUESTION_ACTIVE:
            return self._build_status_response(
                match_id,
                match,
                current_user_firebase_uid,
            )

        # Still waiting - try to match with a bot
        bot = self._pick_random_bot()
        question, q_data = await self._fetch_question_data(
            user_ids=[current_user_firebase_uid],
        )
        await writer.set_opponent_and_question(match_id, bot, q_data)

        # Remove player from queue since they're now matched
        await writer.dequeue_player(current_user_firebase_uid)

        # Submit the bot's answer immediately in the background
        bot_answer = get_bot_answer(question, bot['player_id'])
        bot_correct = AnswerBare(number=question.number, unit=question.unit)
        bot_score = self._scoring.calculate_score(bot_answer, bot_correct)
        await writer.submit_player_answer(
            match_id,
            'player2',
            dict(bot_answer),
            bot_score,
        )

        updated_match = await writer.get_match(match_id)
        return self._build_status_response(
            match_id,
            updated_match or match,
            current_user_firebase_uid,
        )

    async def submit_answer(
        self,
        match_id: str,
        current_user_firebase_uid: str,
        answer: AnswerBare,
        firestore_client: 'AsyncClient',
    ) -> DMAnswerResponse | DMResultResponse:
        """Submit an answer for the current question."""
        writer = DMFirestoreWriter(firestore_client)
        match = await writer.get_match(match_id)
        if not match:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Match not found',
            )

        state = DMState(match['state'])
        if state != DMState.QUESTION_ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Question is not active',
            )

        player_slot = self._get_player_slot(match, current_user_firebase_uid)
        if not player_slot:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='You are not in this match',
            )

        # Score the answer
        correct_answer = AnswerBare(
            number=match['answer_number'],
            unit=match.get('answer_unit'),
        )
        score = self._scoring.calculate_score(answer, correct_answer)

        updated = await writer.submit_player_answer(
            match_id,
            player_slot,
            dict(answer),
            score,
        )

        both_answered = updated.get('player1_answered') and updated.get(
            'player2_answered',
        )

        if both_answered:
            # Resolve: transfer points
            result = await self._resolve_match(
                match_id,
                updated,
                current_user_firebase_uid,
                firestore_client,
            )
            return result

        return DMAnswerResponse(match_id=match_id, waiting_for_opponent=True)

    async def get_result(
        self,
        match_id: str,
        current_user_firebase_uid: str,
        firestore_client: 'AsyncClient',
    ) -> DMResultResponse:
        """Get the result of a resolved match."""
        writer = DMFirestoreWriter(firestore_client)
        match = await writer.get_match(match_id)
        if not match:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Match not found',
            )

        state = DMState(match['state'])
        if state < DMState.QUESTION_RESOLVED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Match not yet resolved',
            )

        player_slot = self._get_player_slot(match, current_user_firebase_uid)
        if not player_slot:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='You are not in this match',
            )

        other_slot = 'player2' if player_slot == 'player1' else 'player1'
        your_points = await self._db.users.get_points(current_user_firebase_uid)

        correct_answer = AnswerBare(
            number=match['answer_number'],
            unit=match.get('answer_unit'),
        )

        return DMResultResponse(
            match_id=match_id,
            winner=match.get('winner'),
            your_score=match.get(f'{player_slot}_score', 0.0),
            opponent_score=match.get(f'{other_slot}_score', 0.0),
            your_answer=match.get(f'{player_slot}_answer', {'number': 0, 'unit': None}),
            opponent_answer=match.get(
                f'{other_slot}_answer',
                {'number': 0, 'unit': None},
            ),
            correct_answer=correct_answer,
            points_transferred=match.get('points_transferred', POINTS_STAKE),
            your_new_points=your_points,
        )

    async def leave(
        self,
        match_id: str,
        current_user_firebase_uid: str,
        firestore_client: 'AsyncClient',
    ) -> DMLeaveResponse:
        """Leave / forfeit a match."""
        writer = DMFirestoreWriter(firestore_client)

        # Remove from queue regardless
        await writer.dequeue_player(current_user_firebase_uid)

        match = await writer.get_match(match_id)
        if not match:
            return DMLeaveResponse(match_id=match_id, forfeited=False)

        state = DMState(match['state'])
        if state == DMState.WAITING_FOR_OPPONENT:
            # Just delete the waiting match
            doc_ref = firestore_client.collection('dm_matches').document(match_id)
            await doc_ref.delete()
            return DMLeaveResponse(match_id=match_id, forfeited=False)

        if state == DMState.QUESTION_ACTIVE:
            # Forfeit - opponent wins
            updated = await writer.forfeit_match(match_id, current_user_firebase_uid)
            if updated and updated.get('winner'):
                winner_id = updated['winner']
                if not is_bot(winner_id):
                    await self._db.users.increment_points(
                        winner_id,
                        POINTS_STAKE,
                    )
                if not is_bot(current_user_firebase_uid):
                    try:
                        await self._db.users.spend_points(
                            current_user_firebase_uid,
                            POINTS_STAKE,
                        )
                    except ValueError:
                        balance = await self._db.users.get_points(
                            current_user_firebase_uid,
                        )
                        if balance > 0:
                            await self._db.users.spend_points(
                                current_user_firebase_uid,
                                balance,
                            )
                await self._db.session.commit()
            return DMLeaveResponse(match_id=match_id, forfeited=True)

        return DMLeaveResponse(match_id=match_id, forfeited=False)

    # ---- Private helpers ----

    async def _resolve_match(
        self,
        match_id: str,
        match: dict[str, Any],
        current_user_firebase_uid: str,
        firestore_client: 'AsyncClient',
    ) -> DMResultResponse:
        """Resolve a completed match: transfer points, record answer events."""
        writer = DMFirestoreWriter(firestore_client)
        winner = match.get('winner')

        p1_id = match['player1']['player_id']
        p2_id = match['player2']['player_id']

        if winner:
            loser = p2_id if winner == p1_id else p1_id
            # Transfer points: winner gains, loser loses (capped at their balance)
            if not is_bot(winner):
                await self._db.users.increment_points(winner, POINTS_STAKE)
            if not is_bot(loser):
                try:
                    await self._db.users.spend_points(loser, POINTS_STAKE)
                except ValueError:
                    # Insufficient balance - take whatever they have
                    loser_balance = await self._db.users.get_points(loser)
                    if loser_balance > 0:
                        await self._db.users.spend_points(loser, loser_balance)
            await self._db.session.commit()

        # Record answer events for non-bot players
        correct_answer = AnswerBare(
            number=match['answer_number'],
            unit=match.get('answer_unit'),
        )
        for slot in ('player1', 'player2'):
            pid = match[slot]['player_id']
            if is_bot(pid):
                continue
            player_answer = match.get(f'{slot}_answer')
            player_score = match.get(f'{slot}_score', 0.0)
            if player_answer:
                event = AnswerEvent(
                    question_uid=uuid.UUID(match['question_uid']),
                    question_difficulty=QuestionDifficulty.MEDIUM,
                    question_category=QuestionCategory.OTHER,
                    user_firebase_id=pid,
                    game_id=match_id,
                    answer=player_answer,
                    correct_answer=correct_answer,
                    score_number=player_score,
                    score_quantile=0.0,
                    game_mode=GameMode.DEATHMATCH,
                )
                await self._db.answers.add_answers([event])

        # Mark finished
        await writer.finish_match(match_id)

        # XP for non-bot players
        for slot in ('player1', 'player2'):
            pid = match[slot]['player_id']
            if is_bot(pid):
                continue
            s = match.get(f'{slot}_score', 0.0)
            xp_inc = int(s // 100)
            if xp_inc > 0:
                await self._db.users.increment_xp(pid, xp_inc)
                await self._db.users.increment_points(pid, xp_inc)
        await self._db.session.commit()

        # Add to user history
        question_uid_str = match['question_uid']
        human_ids = [
            match[s]['player_id']
            for s in ('player1', 'player2')
            if not is_bot(match[s]['player_id'])
        ]
        if human_ids:
            await self._db.users_history.add_questions_to_users_history(
                user_ids=human_ids,
                question_uids=[question_uid_str],
            )

        player_slot = self._get_player_slot(match, current_user_firebase_uid)
        other_slot = 'player2' if player_slot == 'player1' else 'player1'
        your_points = await self._db.users.get_points(current_user_firebase_uid)

        return DMResultResponse(
            match_id=match_id,
            winner=winner,
            your_score=match.get(f'{player_slot}_score', 0.0),
            opponent_score=match.get(f'{other_slot}_score', 0.0),
            your_answer=match.get(f'{player_slot}_answer', {'number': 0, 'unit': None}),
            opponent_answer=match.get(
                f'{other_slot}_answer',
                {'number': 0, 'unit': None},
            ),
            correct_answer=correct_answer,
            points_transferred=POINTS_STAKE,
            your_new_points=your_points,
        )

    async def _fetch_question_data(
        self,
        user_ids: list[str],
    ) -> tuple['Fermi', dict[str, Any]]:
        """Fetch a random unseen question and build Firestore-ready data."""
        human_ids = [uid for uid in user_ids if not is_bot(uid)]
        questions = await self._db.fermi.get_unseen_random_questions(
            count=1,
            for_user_ids=human_ids or user_ids,
        )
        if not questions:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail='No questions available',
            )
        question = questions[0]

        units = get_unit_family(question.unit) if question.unit else None
        quantiles = await self._db.answers.get_question_quantiles(question.uid)
        quantiles_dict = quantiles.model_dump(exclude={'question_uid'})
        upvotes = await self._db.question_votes.get_upvotes(question.uid)

        q_data: dict[str, Any] = {
            'question_uid': str(question.uid),
            'question_text': question.text,
            'question_category': question.category.value if question.category else None,
            'question_difficulty': (
                question.difficulty.value if question.difficulty else None
            ),
            'question_units': units,
            'question_year': question.created_at.year,
            'question_upvotes': upvotes,
            'answer_number': question.number,
            'answer_unit': question.unit,
            'answer_paragraph': question.snippet,
            'answer_quantiles': quantiles_dict,
        }
        return question, q_data

    def _pick_random_bot(self) -> DMPlayer:
        """Pick a random bot as opponent."""
        bot_id = random.choice(list(BOTS.keys()))
        bot = BOTS[bot_id]
        return DMPlayer(
            player_id=bot['id'],
            name=bot['name'],
            picture=bot['picture'],
            points=0,
        )

    @staticmethod
    def _get_player_slot(
        match: dict[str, Any],
        player_id: str,
    ) -> str | None:
        """Return 'player1' or 'player2' based on player_id, or None."""
        p1 = match.get('player1') or {}
        p2 = match.get('player2') or {}
        if p1.get('player_id') == player_id:
            return 'player1'
        if p2.get('player_id') == player_id:
            return 'player2'
        return None

    @staticmethod
    def _build_status_response(
        match_id: str,
        match: dict[str, Any],
        current_user_firebase_uid: str,
    ) -> DMMatchStatusResponse:
        """Build a status response from match data."""
        p1 = match.get('player1') or {}
        is_p1 = p1.get('player_id') == current_user_firebase_uid

        question = None
        if match.get('question_uid'):
            question = DMQuestionData(
                question_uid=match['question_uid'],
                text=match.get('question_text', ''),
                category=match.get('question_category'),
                difficulty=match.get('question_difficulty'),
                units=match.get('question_units'),
                upvotes=match.get('question_upvotes', 0),
                year=match.get('question_year', 0),
            )

        return DMMatchStatusResponse(
            match_id=match_id,
            state=DMState(match['state']),
            player1=match.get('player1'),
            player2=match.get('player2'),
            question=question,
            your_answered=(
                match.get('player1_answered', False)
                if is_p1
                else match.get('player2_answered', False)
            ),
            opponent_answered=(
                match.get('player2_answered', False)
                if is_p1
                else match.get('player1_answered', False)
            ),
        )
