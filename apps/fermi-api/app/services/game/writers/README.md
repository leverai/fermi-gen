# Writers Layer Guide

This directory contains write-focused helpers for the game service. Each writer encapsulates a logical group of Firestore mutations. They were refactored from a broader "Manager" pattern to enforce a clear separation between read and write responsibilities.

Writers are the only place where game-related Firestore documents should be mutated. They are orchestrated by the use-case layer.

## Responsibilities
- Encapsulate all Firestore write logic (create, update, delete).
- Operate on a provided `Writeable` object (`AsyncTransaction` or `AsyncWriteBatch`).
- Remain stateless and side-effect free, beyond the Firestore mutations they perform.
- Raise domain-specific exceptions from `app.services.game.errors` when invariants are violated.
- **Do not** perform Firestore reads (this is the responsibility of `GameRepository`).
- **Do not** raise `fastapi.HTTPException` or have any knowledge of the HTTP layer.

## Usage Example
Writers are injected into use cases and invoked within a transaction or batch.

```python
# From a use case...

class SomeUseCase:
    def __init__(self, *, lifecycle_writer: GameLifecycleWriter, ...):
        self._lifecycle_writer = lifecycle_writer
        ...

    async def execute(self, game_id: str):
        game_ref = self._client.collection('games').document(game_id)

        async def _tx(tx: AsyncTransaction):
            # ... read data via repository ...
            state = GameState(data['state'])

            # Delegate write to the writer
            self._lifecycle_writer.start_game(
                game_ref=game_ref,
                writer=tx,
                state=state,
                n_questions=10
            )

        await self._txn_runner.run(_tx)
```

## Testing Approach
Unit test writers by mocking the `Writeable` collaborator (`AsyncTransaction` or `AsyncWriteBatch`) and asserting that the correct methods (`set`, `update`, `delete`) are called with the expected data.

- Mock the `writer` object (e.g., `unittest.mock.AsyncMock`).
- Call the writer method with test data.
- Assert that `writer.update.assert_called_with(...)` or similar is true.
- Assert that domain exceptions are raised for invalid inputs.
