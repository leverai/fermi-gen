# Use-case Layer Guide

This directory contains one module per endpoint orchestration for the game service. Each use case keeps endpoints thin, centralizes reads via the repository layer, delegates writes to managers, and ensures Firestore transaction semantics remain correct.

## Responsibilities
- Orchestrate a single endpoint flow (validation, reads, domain actions)
- Enforce permissions at the application boundary (raise HTTP-aware errors here)
- Use `GameRepository` for all non-trivial reads (centralized field masks)
- Delegate mutations to managers (no HTTP concerns in managers)
- Start background tasks only after transactions/batches commit

## Dependency Injection
Use cases receive all collaborators via constructor injection. Typical collaborators:
- Firestore `AsyncClient`
- `TransactionRunner` (for transactional use cases)
- `GameRepository` (typed, narrow read APIs)
- Managers for document mutations, e.g. `GameLifecycleManager`, `GamePlayersManager`, `GamePlayersAnswersManager`, `GameQuestionsManager`

Example shape:

```python
class SomeUseCase:
    def __init__(self, *, firestore_client, repo, lifecycle, players, questions, txn_runner=None):
        self._client = firestore_client
        self._repo = repo
        self._lifecycle = lifecycle
        self._players = players
        self._questions = questions
        self._txn_runner = txn_runner
```

## Transactions and Batches
- Keep transaction bodies idempotent and read-before-write
- No external side-effects (network I/O, background tasks) inside transactions
- Prefer batches for write-only groups; use transactions for read–modify–write
- For async usage, go through `TransactionRunner` to standardize behavior

## Testing Approach
- Unit test use cases by mocking collaborators:
  - Mock `GameRepository` methods to return minimal snapshots
  - Mock managers to assert expected mutations are invoked with correct args
  - For transactional flows, stub `TransactionRunner.run` to execute the provided coroutine
- Focus assertions on:
  - Correct permission enforcement and error mapping (HTTP codes)
  - Correct read masks (via repo methods invoked)
  - Correct delegate calls on managers
  - Minimal return payload used for post-commit actions
- Add targeted integration tests around transaction boundaries as needed

## Ownership
- Module docstrings at the top of each use case document responsibilities and boundaries (reads via repo, writes via managers, side-effects post-commit).
- Keep endpoints in `service.py` thin: parse inputs, instantiate use case with dependencies, call `execute`, and schedule any returned background tasks.
