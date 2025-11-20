"""Transaction helpers for Firestore.

This module centralizes async transaction usage to enforce consistent
semantics (idempotent bodies, reads-before-writes, and no side effects
inside the transaction function passed by callers).
"""

from collections.abc import Awaitable, Callable
from typing import TYPE_CHECKING, TypeVar, cast

from google.cloud import firestore

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncClient, AsyncTransaction


T = TypeVar('T')


class TransactionRunner:
    """Runs Firestore async transactions in a standardized way."""

    def __init__(self, client: 'AsyncClient') -> None:
        """Store the Firestore client."""
        self._client = client

    async def run(self, func: Callable[['AsyncTransaction'], Awaitable[T]]) -> T:
        """Execute a Firestore transaction with the provided function.

        The provided ``func`` must be idempotent and follow reads-before-writes
        semantics. This method ensures we do not accidentally schedule any
        side-effects from inside the transaction body.
        """

        @firestore.async_transactional
        async def _wrapper(tx: 'AsyncTransaction') -> T:
            return await func(tx)

        tx = self._client.transaction()
        return cast(T, await _wrapper(tx))
