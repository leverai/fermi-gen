"""API router."""

from fastapi import APIRouter

from app.api.v1.endpoints import (
    account_deletion,
    assets,
    auth,
    daily_question,
    deathmatch,
    game,
    health,
    precision_rush,
    privacy_policy,
    question,
    survival,
    user,
    webhooks,
)

api_router = APIRouter()
api_router.include_router(auth.router, prefix='/auth', tags=['auth'])
api_router.include_router(game.router, prefix='/game', tags=['game'])
api_router.include_router(
    daily_question.router,
    prefix='/daily_question',
    tags=['daily_question'],
)
api_router.include_router(health.router, prefix='/health', tags=['health'])
api_router.include_router(account_deletion.router, tags=['account'])
api_router.include_router(privacy_policy.router, tags=['privacy'])
api_router.include_router(question.router, prefix='/question', tags=['question'])
api_router.include_router(survival.router, prefix='/survival', tags=['survival'])
api_router.include_router(
    precision_rush.router,
    prefix='/precision_rush',
    tags=['precision_rush'],
)
api_router.include_router(user.router, prefix='/user', tags=['user'])
api_router.include_router(
    deathmatch.router,
    prefix='/deathmatch',
    tags=['deathmatch'],
)
api_router.include_router(assets.router, prefix='/assets', tags=['assets'])
api_router.include_router(webhooks.router, prefix='/webhooks', tags=['webhooks'])
