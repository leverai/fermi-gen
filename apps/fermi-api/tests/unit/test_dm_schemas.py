"""Unit tests for deathmatch schemas."""

from app.schemas.deathmatch import (
    POINTS_STAKE,
    DMAnswerRequest,
    DMAnswerResponse,
    DMLeaveResponse,
    DMMatchStatusResponse,
    DMPlayer,
    DMQuestionData,
    DMQueueResponse,
    DMResultResponse,
    DMState,
)


class TestDMState:
    def test_state_ordering(self) -> None:
        assert DMState.WAITING_FOR_OPPONENT < DMState.QUESTION_ACTIVE
        assert DMState.QUESTION_ACTIVE < DMState.QUESTION_RESOLVED
        assert DMState.QUESTION_RESOLVED < DMState.MATCH_FINISHED

    def test_state_values(self) -> None:
        assert DMState.WAITING_FOR_OPPONENT == 0
        assert DMState.QUESTION_ACTIVE == 1
        assert DMState.QUESTION_RESOLVED == 2
        assert DMState.MATCH_FINISHED == 3


class TestDMPlayer:
    def test_player_creation(self) -> None:
        p = DMPlayer(player_id='u1', name='Alice', picture=None, points=100)
        assert p['player_id'] == 'u1'
        assert p['name'] == 'Alice'
        assert p['points'] == 100


class TestPointsStake:
    def test_points_stake_is_50(self) -> None:
        assert POINTS_STAKE == 50


class TestDMQueueResponse:
    def test_waiting_response(self) -> None:
        r = DMQueueResponse(match_id='m-1', status='waiting')
        assert r.match_id == 'm-1'
        assert r.status == 'waiting'

    def test_matched_response(self) -> None:
        r = DMQueueResponse(match_id='m-2', status='matched')
        assert r.status == 'matched'


class TestDMAnswerRequest:
    def test_request_fields(self) -> None:
        r = DMAnswerRequest(
            match_id='m-1',
            answer={'number': 42.0, 'unit': None},
        )
        assert r.match_id == 'm-1'
        assert r.answer['number'] == 42.0


class TestDMAnswerResponse:
    def test_waiting_response(self) -> None:
        r = DMAnswerResponse(match_id='m-1', waiting_for_opponent=True)
        assert r.waiting_for_opponent is True


class TestDMResultResponse:
    def test_result_with_winner(self) -> None:
        r = DMResultResponse(
            match_id='m-1',
            winner='u1',
            your_score=5000.0,
            opponent_score=3000.0,
            your_answer={'number': 90, 'unit': None},
            opponent_answer={'number': 50, 'unit': None},
            correct_answer={'number': 100, 'unit': None},
            points_transferred=50,
            your_new_points=250,
        )
        assert r.winner == 'u1'
        assert r.points_transferred == 50

    def test_result_draw(self) -> None:
        r = DMResultResponse(
            match_id='m-1',
            winner=None,
            your_score=4000.0,
            opponent_score=4000.0,
            your_answer={'number': 80, 'unit': None},
            opponent_answer={'number': 80, 'unit': None},
            correct_answer={'number': 100, 'unit': None},
            points_transferred=50,
            your_new_points=200,
        )
        assert r.winner is None


class TestDMLeaveResponse:
    def test_forfeited(self) -> None:
        r = DMLeaveResponse(match_id='m-1', forfeited=True)
        assert r.forfeited is True

    def test_not_forfeited(self) -> None:
        r = DMLeaveResponse(match_id='m-1', forfeited=False)
        assert r.forfeited is False


class TestDMMatchStatusResponse:
    def test_waiting_status(self) -> None:
        r = DMMatchStatusResponse(
            match_id='m-1',
            state=DMState.WAITING_FOR_OPPONENT,
            player1={'player_id': 'u1', 'name': 'A', 'picture': None, 'points': 100},
        )
        assert r.state == DMState.WAITING_FOR_OPPONENT
        assert r.player2 is None

    def test_active_status_with_question(self) -> None:
        q = DMQuestionData(
            question_uid='q-1',
            text='How many?',
        )
        r = DMMatchStatusResponse(
            match_id='m-1',
            state=DMState.QUESTION_ACTIVE,
            player1={'player_id': 'u1', 'name': 'A', 'picture': None, 'points': 100},
            player2={'player_id': 'u2', 'name': 'B', 'picture': None, 'points': 80},
            question=q,
        )
        assert r.question is not None
        assert r.question.question_uid == 'q-1'
