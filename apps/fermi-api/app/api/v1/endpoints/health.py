"""Add health check endpoint."""

from typing import Literal

from fastapi import APIRouter, status

router = APIRouter()


@router.get('/health')
async def health_check() -> Literal[200]:
    """Health check endpoint."""
    return status.HTTP_200_OK
