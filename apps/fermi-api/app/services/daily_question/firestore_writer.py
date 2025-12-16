"""Firestore writer for Daily Question mode.

Manages the Firestore documents that clients listen to for real-time updates.
"""

import datetime
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncClient


class DQFirestoreWriter:
    """Manages Firestore documents for Daily Question mode."""

    COLLECTION = 'daily_questions'
    USER_SESSIONS_SUBCOLLECTION = 'user_sessions'

    def __init__(self, firestore_client: 'AsyncClient') -> None:
        """Initialize the writer.

        Args:
            firestore_client: The Firestore async client.

        """
        self._fs = firestore_client

    def _date_to_doc_id(self, date: datetime.date) -> str:
        """Convert a date to a document ID.

        Args:
            date: The date.

        Returns:
            Document ID in YYYY-MM-DD format.

        """
        return date.strftime('%Y-%m-%d')

    async def create_dq_document(
        self,
        date: datetime.date,
        question_uid: str,
        window_start_utc: datetime.datetime,
        window_end_utc: datetime.datetime,
    ) -> None:
        """Create the daily question Firestore document.

        Args:
            date: The date for this DQ.
            question_uid: The question's UID.
            window_start_utc: Window start time in UTC.
            window_end_utc: Window end time in UTC.

        """
        doc_id = self._date_to_doc_id(date)
        doc_ref = self._fs.collection(self.COLLECTION).document(doc_id)

        await doc_ref.set(
            {
                'question_uid': question_uid,
                'status': 'ACTIVE',
                'window_start': window_start_utc.isoformat(),
                'window_end': window_end_utc.isoformat(),
                'results_ready': False,
            },
        )

    async def set_results_ready(self, date: datetime.date) -> None:
        """Mark the daily question as having results ready.

        Args:
            date: The date for this DQ.

        """
        doc_id = self._date_to_doc_id(date)
        doc_ref = self._fs.collection(self.COLLECTION).document(doc_id)

        await doc_ref.update(
            {
                'status': 'RESULTS',
                'results_ready': True,
            },
        )

    async def record_user_start(
        self,
        date: datetime.date,
        user_id: str,
        started_at_utc: datetime.datetime,
        answer_deadline_utc: datetime.datetime,
    ) -> None:
        """Record that a user has started the daily question.

        Args:
            date: The date for this DQ.
            user_id: The user's Firebase UID.
            started_at_utc: When the user started.
            answer_deadline_utc: The user's answer deadline.

        """
        doc_id = self._date_to_doc_id(date)
        session_ref = (
            self._fs.collection(self.COLLECTION)
            .document(doc_id)
            .collection(self.USER_SESSIONS_SUBCOLLECTION)
            .document(user_id)
        )

        await session_ref.set(
            {
                'started_at': started_at_utc.isoformat(),
                'answer_deadline': answer_deadline_utc.isoformat(),
                'submitted': False,
            },
        )

    async def mark_user_submitted(self, date: datetime.date, user_id: str) -> None:
        """Mark a user as having submitted their answer.

        Args:
            date: The date for this DQ.
            user_id: The user's Firebase UID.

        """
        doc_id = self._date_to_doc_id(date)
        session_ref = (
            self._fs.collection(self.COLLECTION)
            .document(doc_id)
            .collection(self.USER_SESSIONS_SUBCOLLECTION)
            .document(user_id)
        )

        await session_ref.update(
            {
                'submitted': True,
            },
        )

    async def get_user_session(
        self,
        date: datetime.date,
        user_id: str,
    ) -> dict | None:
        """Get a user's session document.

        Args:
            date: The date for this DQ.
            user_id: The user's Firebase UID.

        Returns:
            The session data as a dict, or None if not found.

        """
        doc_id = self._date_to_doc_id(date)
        session_ref = (
            self._fs.collection(self.COLLECTION)
            .document(doc_id)
            .collection(self.USER_SESSIONS_SUBCOLLECTION)
            .document(user_id)
        )

        doc = await session_ref.get()
        if doc.exists:
            return doc.to_dict()
        return None

    async def get_dq_document(self, date: datetime.date) -> dict | None:
        """Get the daily question document.

        Args:
            date: The date for this DQ.

        Returns:
            The DQ document data as a dict, or None if not found.

        """
        doc_id = self._date_to_doc_id(date)
        doc_ref = self._fs.collection(self.COLLECTION).document(doc_id)

        doc = await doc_ref.get()
        if doc.exists:
            return doc.to_dict()
        return None
