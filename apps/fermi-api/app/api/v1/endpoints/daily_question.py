"""Daily Question endpoints."""

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, Request
from fastapi.responses import HTMLResponse
from fermi_core.units import Locale
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_authenticated_user, get_current_user, require_pro
from app.api.v1.authenticated_user import AuthenticatedUser
from app.api.v1.dependencies import (
    get_daily_question_service,
    get_firestore_client,
    get_user_service,
    verify_scheduler_secret,
)
from app.api.v1.rate_limit import DQ_START_RATE_LIMIT, limiter
from app.services.daily_question.schemas import (
    DQAnswerRequest,
    DQEndResponse,
    DQLiteArchiveResponse,
    DQPostTakeAnswerRequest,
    DQPostTakeResultsResponse,
    DQQuestionResponse,
    DQResultsResponse,
    DQSubmitResponse,
)
from app.services.daily_question.service import DailyQuestionService
from app.services.user import UserService

router = APIRouter()


@router.post('/start', response_model=DQQuestionResponse)
@limiter.limit(DQ_START_RATE_LIMIT)
async def start_question(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQQuestionResponse:
    """Start the daily question for the current user.

    Returns the question with the answer deadline.
    User has 30 seconds (or until window end, whichever is sooner) to answer.
    The DQ must be ACTIVE (12PM - 2AM UTC) for users to start.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, start_question.__qualname__)

    result = await dq_service.start_question(
        user_firebase_uid=current_user.firebase_uid,
        firestore_client=firestore_client,
    )

    return result


@router.post('/answer', response_model=DQSubmitResponse)
async def submit_answer(
    payload: DQAnswerRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    user_service: Annotated[UserService, Depends(get_user_service)],
) -> DQSubmitResponse:
    """Submit an answer for the daily question.

    Must be called within the answer deadline (30s + 5s grace after starting,
    or before window end + 20s grace, whichever is sooner).
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, submit_answer.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'answer={payload.answer}')

    result = await dq_service.submit_answer(
        user_firebase_uid=current_user.firebase_uid,
        answer=payload.answer,
        firestore_client=firestore_client,
        user_service=user_service,
    )

    return result


@router.get('/results', response_model=DQResultsResponse)
async def get_results(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQResultsResponse:
    """Get results for today's daily question.

    Only available after the DQ is CLOSED (after 2AM UTC next day).
    Returns user's score, rank, and leaderboard.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_results.__qualname__)

    result = await dq_service.get_results(
        user_firebase_uid=current_user.firebase_uid,
        user_locale=Locale(current_user.locale),
    )

    return result


@router.get('/results/{question_date}', response_model=DQResultsResponse)
async def get_results_for_date(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    question_date: str = Path(
        ...,
        pattern=r'^\d{4}-\d{2}-\d{2}$',
        description='Date in YYYY-MM-DD format',
    ),
    *,
    include_post_takes: bool = Query(
        default=True,
        description='Include post-take entries in leaderboard',
    ),
) -> DQResultsResponse:
    """Get results for a specific daily question by date.

    Use this to view results for past daily questions.
    Only available for CLOSED DQs.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_results_for_date.__qualname__)
    span.set_attribute(
        api_attrs.QUERY_PARAMS,
        f'question_date={question_date}, include_post_takes={include_post_takes}',
    )

    parsed_date = datetime.strptime(question_date, '%Y-%m-%d').date()  # noqa: DTZ007
    return await dq_service.get_results_for_date(
        user_firebase_uid=current_user.firebase_uid,
        question_date=parsed_date,
        user_locale=Locale(current_user.locale),
        include_post_takes=include_post_takes,
    )


@router.get('/archive/week', response_model=DQLiteArchiveResponse)
async def get_archive_week(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQLiteArchiveResponse:
    """Get the latest eight DQs for the carousel.

    Returns a lightweight response with dates and participation status.
    Use this for the main screen DQ carousel.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_archive_week.__qualname__)

    return await dq_service.get_lite_archive_week(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/archive/month', response_model=DQLiteArchiveResponse)
async def get_archive_month(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    year: int = Query(..., ge=2020, le=2100, description='Year (e.g., 2024)'),
    month: int = Query(..., ge=1, le=12, description='Month (1-12)'),
) -> DQLiteArchiveResponse:
    """Get lite archive for a specific month (calendar view).

    Returns a lightweight response with dates and participation status.
    Use this for the archive calendar sheet.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_archive_month.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'year={year}, month={month}')

    return await dq_service.get_lite_archive_month(
        user_firebase_uid=current_user.firebase_uid,
        year=year,
        month=month,
    )


@router.post('/post_take/{question_date}/start', response_model=DQQuestionResponse)
@limiter.limit(DQ_START_RATE_LIMIT)
async def start_post_take(
    request: Request,
    auth_user: Annotated[AuthenticatedUser, Depends(get_authenticated_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    question_date: str = Path(
        ...,
        pattern=r'^\d{4}-\d{2}-\d{2}$',
        description='Date in YYYY-MM-DD format',
    ),
    *,
    with_ad: bool = Query(
        default=False,
        description='Allow access after watching a rewarded ad (bypasses Pro check)',
    ),
) -> DQQuestionResponse:
    """Start a post-take for a closed daily question.

    Post-take allows Pro users or Free users who watched an ad to take older DQs.
    The DQ must be CLOSED (not SCHEDULED or ACTIVE).
    Requires Pro subscription unless with_ad=True.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, start_post_take.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'question_date={question_date}')

    if not with_ad:
        require_pro(auth_user, 'Archive access')

    parsed_date = datetime.strptime(question_date, '%Y-%m-%d').date()  # noqa: DTZ007
    return await dq_service.start_post_take_question(
        user_firebase_uid=auth_user.firebase_uid,
        question_date=parsed_date,
    )


@router.post(
    '/post_take/{question_date}/answer',
    response_model=DQPostTakeResultsResponse,
)
async def submit_post_take_answer(
    payload: DQPostTakeAnswerRequest,
    auth_user: Annotated[AuthenticatedUser, Depends(get_authenticated_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    question_date: str = Path(
        ...,
        pattern=r'^\d{4}-\d{2}-\d{2}$',
        description='Date in YYYY-MM-DD format',
    ),
    *,
    with_ad: bool = Query(
        default=False,
        description='Allow access after watching a rewarded ad (bypasses Pro check)',
    ),
) -> DQPostTakeResultsResponse:
    """Submit an answer for a post-take and get immediate results.

    Returns score, rank, and full results immediately after submission.
    Must be submitted within 30s + grace period of started_at.
    Requires Pro subscription unless with_ad=True.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, submit_post_take_answer.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'question_date={question_date}')

    if not with_ad:
        require_pro(auth_user, 'Archive access')

    parsed_date = datetime.strptime(question_date, '%Y-%m-%d').date()  # noqa: DTZ007
    return await dq_service.submit_post_take_answer(
        user_firebase_uid=auth_user.firebase_uid,
        question_date=parsed_date,
        answer=payload.answer,
        started_at=payload.started_at,
        user_locale=Locale(auth_user.locale),
    )


@router.post('/close_and_schedule', response_model=DQEndResponse)
async def close_and_schedule_dq(
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    _: Annotated[None, Depends(verify_scheduler_secret)],
) -> DQEndResponse:
    """End the active DQ and schedule the next one.

    Called by Cloud Scheduler at 2AM UTC to:
    1. Close the DQ document in Firestore
    2. Close the DQ entry in the database
    3. Compute and update participant ranks
    4. Schedule the next day's DQ
    5. Set results_ready in Firestore

    # Authentication: Cloud Scheduler sends OIDC token (verified at Cloud Run level)
    # and X-Scheduler-Secret header (verified here for defense-in-depth).

    Args:
        firestore_client: Firestore client (injected).
        dq_service: Daily Question service (injected).

    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, close_and_schedule_dq.__qualname__)

    return await dq_service.close_active_and_schedule_new_dq(
        firestore_client=firestore_client,
    )


@router.post('/activate')
async def activate_dq(
    request: Request,
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    _: Annotated[None, Depends(verify_scheduler_secret)],
) -> None:
    """Activate the scheduled DQ for this date.

    Invoked by a scheduled job at 12PM UTC.

    # Authentication: Cloud Scheduler sends OIDC token (verified at Cloud Run level)
    # and X-Scheduler-Secret header (verified here for defense-in-depth).

    Args:
        request: FastAPI request object.
        firestore_client: Firestore client (injected).
        dq_service: Daily Question service (injected).

    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, activate_dq.__qualname__)

    await dq_service.activate_scheduled_dq(
        request=request,
        firestore_client=firestore_client,
    )


@router.get('/invite/{question_date}', response_class=HTMLResponse)
async def invite_to_dq(
    question_date: str = Path(
        ...,
        pattern=r'^\d{4}-\d{2}-\d{2}$',
        description='Date in YYYY-MM-DD format',
    ),
) -> HTMLResponse:
    """Deep link trampoline for DQ invites.

    Returns HTML that attempts to open the app with a deep link,
    with fallback to app stores if the app is not installed.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, invite_to_dq.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'question_date={question_date}')

    # TODO: Make these configurable
    play_store_url = (
        'https://play.google.com/store/apps/details?id=tech.leverai.guesstimate'
    )
    app_store_url = 'https://apps.apple.com/app/id6756033242'
    app_package = 'tech.leverai.guesstimate'
    deep_link = f'guesstimate://dq/{question_date}'

    # Android intent URI - more reliable than custom scheme for Chrome/WebView
    # Format: intent://HOST/PATH#Intent;scheme=SCHEME;package=PACKAGE;end
    intent_uri = (
        f'intent://dq/{question_date}#Intent;'
        f'scheme=guesstimate;'
        f'package={app_package};'
        f'S.browser_fallback_url={play_store_url};'
        'end'
    )

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Daily Question</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body>
        <p>Opening Daily Question...</p>
        <script>
            var deepLink = "{deep_link}";
            var intentUri = "{intent_uri}";
            var playStoreUrl = "{play_store_url}";
            var appStoreUrl = "{app_store_url}";

            var userAgent = navigator.userAgent || navigator.vendor || window.opera;
            var isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;
            var isAndroid = /android/i.test(userAgent);

            if (isIOS) {{
                // iOS: Try custom scheme, fallback to App Store
                window.location.href = deepLink;
                setTimeout(function() {{
                    window.location.href = appStoreUrl;
                }}, 2000);
            }} else if (isAndroid) {{
                // Android: Use intent URI for reliable app launch
                // Intent URI handles fallback automatically via S.browser_fallback_url
                window.location.href = intentUri;
            }} else {{
                // Other platforms: Try custom scheme, fallback to Play Store
                window.location.href = deepLink;
                setTimeout(function() {{
                    window.location.href = playStoreUrl;
                }}, 2000);
            }}
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=200)
