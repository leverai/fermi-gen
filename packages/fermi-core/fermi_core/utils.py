"""Utility functions for the Fermi core."""

import datetime
from typing import TYPE_CHECKING, Any, TypeVar, cast

from langchain.chat_models import init_chat_model
from langchain_core.language_models import BaseChatModel
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import Runnable

if TYPE_CHECKING:
    from pydantic import AwareDatetime, BaseModel


InputT = TypeVar('InputT')
OutputT = TypeVar('OutputT', bound='BaseModel')


def create_generic_chain(
    *,
    model: str,
    model_provider: str,
    prompt: ChatPromptTemplate,
    output_schema: type[OutputT],
    input_schema: type[InputT] = object,  # For type hinting only
    **model_kwargs: Any,
) -> Runnable[InputT, OutputT]:
    """Create a LangChain runnable with generic input/output schemas."""
    llm = cast(
        BaseChatModel,
        init_chat_model(model, model_provider=model_provider, **model_kwargs),
    )
    structured_llm = llm.with_structured_output(output_schema)
    chain = cast(
        Runnable[InputT, OutputT],
        (prompt | structured_llm).with_retry(),
    )
    return chain


def utc_now() -> 'AwareDatetime':
    """Get the current UTC time."""
    return datetime.datetime.now(datetime.UTC)


def utcnow_naive() -> datetime.datetime:
    """Return a naive datetime guaranteed to be UTC."""
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None)
