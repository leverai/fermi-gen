# Game Service Architecture

This directory contains the core logic for the game service. It follows a clean architecture pattern to separate concerns, improve testability, and enforce correct Firestore transaction semantics.

## Directory Structure Overview

- `service.py`: The public-facing entry point for the service. It acts as a thin facade that receives requests from the API layer, instantiates the appropriate use case, injects dependencies, and schedules any post-commit background tasks. It does not contain business logic or transaction details.

- `use_cases/`: Contains one module per endpoint, each orchestrating a specific user-facing operation (e.g., `join_game`, `submit_answer`). This is the only layer that should raise HTTP-aware exceptions and coordinate reads, writes, and background tasks. See the `use_cases/README.md` for more details.

- `writers/`: Contains stateless, write-only helpers that perform all Firestore mutations. They operate on a provided transaction or batch, raise domain-specific exceptions, and have no knowledge of the HTTP layer or Firestore reads. See the `writers/README.md` for more details.

- `repositories/`: Centralizes all Firestore read operations. The `GameRepository` provides narrow, typed methods with clear field masks to ensure transactions are efficient and consistent. All reads required by use cases should go through this layer.

- `gateways/`: Acts as an adapter layer to external services. The `AnalyticsGateway` encapsulates all communication with the Postgres analytics database, keeping the core service decoupled from the analytics schema. The underlying data access is now implemented using `SQLModel`, with the `DatabaseClient` from the `fermi-db` package managing repository access within a request-scoped database session.

- `tasks/`: Contains modules for background operations that must run after a transaction commits (post-commit side effects). Examples include fetching questions for a new game or archiving game results.

- `transactions/`: Provides a standardized `TransactionRunner` to ensure Firestore transactions are executed safely and idempotently, preventing side effects from being scheduled inside a transaction body.

- `errors.py`: Defines custom, domain-specific exceptions (e.g., `StateConflictError`, `NotFoundError`) that are raised by writers and other low-level modules. These are translated to HTTP exceptions at the use-case boundary.

- `utils.py`: Contains shared constants and simple, pure helper functions used across the service.

## Architectural Flow

A typical request flows through the system as follows:
1. An API endpoint calls a method in `service.py`.
2. The service method instantiates the corresponding **use case** class.
3. The use case executes the flow, reading data via the **repository**.
4. For any mutations, the use case invokes methods on the **writers**, typically within a transaction managed by the **transaction runner**.
5. If the operation requires interaction with another database, it calls a **gateway**.
6. The use case returns a result to the service, which may include data needed to schedule a background **task**.
7. The service schedules the task and returns the final response to the API layer.
