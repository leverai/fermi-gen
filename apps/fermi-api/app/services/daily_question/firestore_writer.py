"""Firestore writer for Daily Question mode.

Manages the Firestore documents that clients listen to for real-time updates.
"""

import datetime
from typing import TYPE_CHECKING, cast

from app.services.daily_question.schemas import DqDoc, DQUserSession, DQWindowStatus

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
        """Create the daily question Firestore document with NOT_STARTED status.

        This is called when the DQ is scheduled (at 2AM UTC).
        The document will be updated to ACTIVE status at 12PM UTC.

        Args:
            date: The date for this DQ.
            question_uid: The question's UID.
            window_start_utc: Window start time in UTC (12PM UTC).
            window_end_utc: Window end time in UTC (2AM UTC next day).

        """
        doc_id = self._date_to_doc_id(date)
        doc_ref = self._fs.collection(self.COLLECTION).document(doc_id)

        await doc_ref.set(
            DqDoc(  # type: ignore
                question_uid=question_uid,
                status=DQWindowStatus.NOT_STARTED,
                window_start=window_start_utc,
                window_end=window_end_utc,
                results_ready=False,
            ),
        )

    async def activate_dq_document(
        self,
        date: datetime.date,
        invite_url: str | None = None,
    ) -> None:
        """Update the daily question document status to ACTIVE.

        This is called when the DQ window opens (at 12PM UTC).

        Args:
            date: The date for this DQ.
            invite_url: Optional invite URL for sharing.

        """
        doc_id = self._date_to_doc_id(date)
        doc_ref = self._fs.collection(self.COLLECTION).document(doc_id)

        update_data: dict[str, str] = {'status': DQWindowStatus.ACTIVE}
        if invite_url:
            update_data['invite_url'] = invite_url

        await doc_ref.update(update_data)

    async def close_dq_document(self, date: datetime.date) -> None:
        """Close the daily question document.

        This is called when the DQ window closes (at 2AM UTC next day).

        Args:
            date: The date for this DQ.

        """
        doc_id = self._date_to_doc_id(date)
        doc_ref = self._fs.collection(self.COLLECTION).document(doc_id)

        await doc_ref.update(
            {
                'status': DQWindowStatus.CLOSED,
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
                'started_at': started_at_utc,
                'answer_deadline': answer_deadline_utc,
                'submitted': False,
            },
        )

    async def delete_user_session(self, date: datetime.date, user_id: str) -> None:
        """Delete the user session document after submission.

        The session is deleted after the user submits their answer,
        whether on-time or late.

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

        await session_ref.delete()

    async def mark_user_submitted(self, date: datetime.date, user_id: str) -> None:
        """Mark the user session as submitted.

        Updates the session document to indicate the user has submitted,
        rather than deleting it, so we can track participation status.

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

        await session_ref.update({'submitted': True})

    async def get_user_session(
        self,
        date: datetime.date,
        user_id: str,
    ) -> DQUserSession | None:
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
            return cast(DQUserSession, doc.to_dict())
        return None

    async def get_dq_document(self, date: datetime.date) -> DqDoc | None:
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
            return cast(DqDoc, doc.to_dict())
        return None
