"""Repository for seed-related database operations."""

import logging
from typing import cast

from pydantic import BaseModel
from sqlmodel import select

from fermi_db.models import Seed
from fermi_db.repositories import BaseRepository

logger = logging.getLogger(__name__)


class SeedLight(BaseModel):
    """Lightweight seed model with only id and text (no embedding)."""

    id: int
    seed: str


class SeedRepository(BaseRepository):
    """Handle database operations related to seeds."""

    async def get_seed_by_id(self, seed_id: int) -> Seed | None:
        """Get a seed by its ID."""
        statement = select(Seed).where(Seed.id == seed_id)
        result = await self.session.exec(statement)
        return result.one_or_none()

    async def get_seeds_by_ids(self, seed_ids: list[int]) -> list[Seed]:
        """Get multiple seeds by their IDs in a single query.

        Args:
            seed_ids: List of seed IDs to fetch

        Returns:
            List of Seed objects (may be fewer than requested if some IDs don't exist)

        """
        if not seed_ids:
            return []

        statement = select(Seed).where(Seed.id.in_(seed_ids))  # type: ignore
        result = await self.session.exec(statement)
        return list(result.all())

    async def get_seeds_light_by_ids(self, seed_ids: list[int]) -> list[SeedLight]:
        """Get multiple seeds (id and text only) by their IDs.

        This method only fetches id and seed text, excluding the embedding
        vector for better performance when embeddings are not needed.

        Args:
            seed_ids: List of seed IDs to fetch

        Returns:
            List of SeedLight objects (id and text only)

        """
        if not seed_ids:
            return []

        statement = select(Seed.id, Seed.seed).where(Seed.id.in_(seed_ids))  # type: ignore
        result = await self.session.exec(statement)
        seeds = []
        for row in result.all():
            seed_id, seed_text = row
            if seed_id is not None:  # Primary key, always set
                seeds.append(SeedLight(id=seed_id, seed=seed_text))
        return seeds

    async def get_all_seeds_light(self) -> list[SeedLight]:
        """Get all seeds (id and text only).

        Returns:
            List of all SeedLight objects (id and text only)

        """
        statement = select(Seed.id, Seed.seed)
        result = await self.session.exec(statement)
        seeds = []
        for row in result.all():
            seed_id, seed_text = row
            if seed_id is not None:  # Primary key, always set
                seeds.append(SeedLight(id=seed_id, seed=seed_text))
        return seeds

    async def find_similar_seeds(
        self,
        embedding: list[float],
        threshold: float = 0.9,
    ) -> list[tuple[Seed, float]]:
        """Find similar seeds using cosine distance.

        Args:
            embedding: The embedding vector to compare against
            threshold: Maximum cosine distance for similarity (default 0.9)

        Returns:
            List of (Seed, distance) tuples where distance <= threshold

        """
        statement = (
            select(
                Seed,
                Seed.embedding.cosine_distance(embedding).label('distance'),  # type: ignore
            )
            .where(Seed.embedding.cosine_distance(embedding) <= threshold)  # type: ignore
            .order_by('distance')
        )
        result = await self.session.exec(statement)
        return list(result.all())

    async def insert_unique_seed(
        self,
        seed: Seed,
        threshold: float = 0.9,
    ) -> int | None:
        """Insert a seed only if it's semantically unique.

        Args:
            seed: The seed to insert
            threshold: Maximum cosine distance for similarity check

        Returns:
            The inserted seed ID if unique, None if too similar to existing seed

        """
        similar = await self.find_similar_seeds(seed.embedding, threshold)
        if similar:
            db_seed, distance = similar[0]
            # Too similar to existing seed, reject
            logger.info(
                f'Similar seed found. Seed: {seed.seed}. '
                f'Existing seed: {db_seed.seed}. Distance: {distance:.4f}',
            )
            return None

        # Insert new seed
        self.session.add(seed)
        await self.session.commit()
        await self.session.refresh(seed)
        return seed.id

    async def get_all_seed_ids(self) -> list[int]:
        """Get all seed IDs in the database."""
        statement = select(Seed.id)
        result = await self.session.exec(statement)
        return cast(list[int], list(result.all()))
