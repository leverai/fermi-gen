"""Core embedding logic for the fermi-embed package."""

import re
import unicodedata

from ftfy import fix_text
from langchain_openai import OpenAIEmbeddings
from openai import AsyncOpenAI


def clean_text_for_embedding(string: str, *, to_lower: bool = False) -> str:
    r"""Clean and normalize input text before generating embeddings.

    This function standardizes text to eliminate encoding noise and inconsistent
    punctuation that can negatively affect embedding quality. It optionally
    lowercases the text to further improve consistency across inputs.

    The cleaning steps include:
      1. Fixing common encoding and typographic issues using `ftfy.fix_text()`.
      2. Normalizing Unicode text using `unicodedata.normalize('NFKC')` to ensure
         canonical representation and compatibility folding.
      3. Replacing non-ASCII punctuation (e.g., curly quotes, typographic dashes)
         with their ASCII equivalents.
      4. Collapsing excessive whitespace and trimming leading/trailing spaces.
      5. Optionally converting the text to lowercase for consistent embeddings.

    Args:
        string (str): The raw input text to clean. Can include mixed encodings,
            typographic punctuation, or other Unicode artifacts.
        to_lower (bool, optional): Whether to convert the cleaned text to
            lowercase. Defaults to False.

    Returns:
        str: A cleaned, normalized string ready for embedding.

    Example:
        >>> text = 'Here’s an Example — with “Smart Quotes” and Weird-Hyphens…'
        >>> clean_text_for_embedding(text)
        'Here\'s an Example - with "Smart Quotes" and Weird-Hyphens...'

        >>> clean_text_for_embedding(text, to_lower=True)
        'here\'s an example - with "smart quotes" and weird-hyphens...'

    Notes:
        - The cleaning process may remove or simplify some Unicode symbols.
        - Lowercasing can improve similarity consistency but may remove casing
          distinctions useful in some embedding models.
        - Always use the same cleaning configuration during both data ingestion
          and query-time embedding to ensure consistency.

    """  # noqa: RUF002
    # 1. Fix encoding/typographic issues
    string = fix_text(string)

    # 2. Unicode normalization
    string = unicodedata.normalize('NFKC', string)

    # 3. Replace curly quotes and typographic dashes
    string = re.sub(r'[“”«»„‛‟‹›]', '"', string)  # noqa: RUF001
    string = re.sub(r'[‘’‚‛❛❜]', "'", string)  # noqa: RUF001
    string = re.sub(r'[‐-‒–—−﹣]', '-', string)  # noqa: RUF001

    # 4. Normalize whitespace
    string = re.sub(r'\s+', ' ', string).strip()

    # 5. Optionally convert to lowercase
    if to_lower:
        string = string.lower()

    return string


async def aget_embeddings_clean_3small(strings: list[str]) -> list[list[float]]:
    """Embed a batch of strings using OpenAI and return the vectors."""
    strings = [clean_text_for_embedding(s) for s in strings]
    embeddings_model = OpenAIEmbeddings(model='text-embedding-3-small')
    vectors = await embeddings_model.aembed_documents(strings)
    return vectors


async def aget_query_embedding_3small(text: str) -> list[float]:
    """Embed one query via the OpenAI SDK directly (langchain-free hot path).

    Applies the SAME ``clean_text_for_embedding`` as the corpus so the query lands
    in the same vector space as ``aget_embeddings_clean_3small`` (vector-space
    parity is non-negotiable for the similarity gate). Uses the ``openai`` SDK
    directly rather than the langchain path, keeping langchain/tiktoken off the
    user-facing request path; the resulting vectors agree with the langchain path
    to ~0.9999 cosine for query-length text.
    """
    cleaned = clean_text_for_embedding(text)  # SAME cleaning as the corpus
    resp = await AsyncOpenAI().embeddings.create(
        model='text-embedding-3-small',
        input=cleaned,
    )
    return resp.data[0].embedding
