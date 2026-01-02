from pathlib import Path
from langchain_core.prompts import ChatPromptTemplate


ASK_PROMPT = ChatPromptTemplate.from_messages(
    [
        ('system', (Path(__file__).parent / 'ASK_PROMPT.md').read_text()),
        (
            'human',
            (
                'Generate a batch of no more than {num_questions} questions. Your seed: **{seed}**'
            ),
        ),
    ],
)


EXTRACT_INFO_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            'system',
            (Path(__file__).parent / 'EXTRACT_INFO_PROMPT.md').read_text(),
        ),
        (
            'human',
            'Analyze the following Question and Answer Paragraph, and extract the required information.\n'
            'Question: **{question}**\n'
            'Answer Paragraph: **{paragraph}**\n',
        ),
    ],
)


SELECT_LOCATION_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            'system',
            (Path(__file__).parent / 'SELECT_LOCATION_PROMPT.md').read_text(),
        ),
        (
            'human',
            'Select the best country code for searching this Fermi question: **{question}**',
        ),
    ],
)


CATEGORIZE_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            'system',
            (Path(__file__).parent / 'CATEGORIZE_PROMPT.md').read_text(),
        ),
        (
            'human',
            'Categorize the following Fermi question: **{question}**',
        ),
    ],
)


DIFFICULTY_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            'system',
            (Path(__file__).parent / 'DIFFICULTY_PROMPT.md').read_text(),
        ),
        (
            'human',
            'Assess the difficulty of the following Fermi question: **{question}**',
        ),
    ],
)


LLM_ANSWER_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            'system',
            (Path(__file__).parent / 'LLM_ANSWER_PROMPT.md').read_text(),
        ),
        (
            'human',
            'Answer the following Fermi question: **{question}**\nUnit: **{answer_unit}**',
        ),
    ],
)
