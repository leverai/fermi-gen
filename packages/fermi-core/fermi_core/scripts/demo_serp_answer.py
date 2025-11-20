"""Demo script for testing SerpAPI answer pipeline."""

import asyncio
import json
from pathlib import Path

from fermi_core.op.answer_serp import aget_questions_answers_serp


async def main() -> None:
    """Run demo of SerpAPI answer pipeline."""
    questions = [
        'How many marbles can fit inside an elephant trunk?',
        'How much popcorn is eaten in the U.S. each year?',
        'How many songs were played in the background of Greys Anatomy episodes?',
    ]

    print('=== SerpAPI Answer Pipeline Demo ===\n')
    print(f'Testing with {len(questions)} questions...\n')

    answers = await aget_questions_answers_serp(
        questions,
        location_model='phi4-reasoning:plus',  # 'gpt-4o-mini',  # Cheap for simple task
        extraction_model='phi4-reasoning:plus',  # High quality for critical task
        model_provider='ollama',
    )

    print('\n=== Results ===\n')

    # Prepare results for JSON serialization
    results_json = []
    for q, a in zip(questions, answers, strict=True):
        print(f'Q: {q}')
        if isinstance(a, BaseException):
            print(f'Error: {type(a).__name__}: {a}\n')
            results_json.append(
                {
                    'question': q,
                    'success': False,
                    'error_type': type(a).__name__,
                    'error_message': str(a),
                },
            )
        else:
            print(f'A: {a.number} {a.unit or "(dimensionless)"}')
            print(f'Snippet: {a.snippet[:200]}...')
            print(f'Confidence: {a.confidence}')
            print(f'Used AI Overview: {a.used_ai_overview}')
            print()
            results_json.append(
                {
                    'question': q,
                    'success': True,
                    'answer': a.model_dump(mode='json'),
                },
            )

    # Save results to JSON file
    output_file = Path(__file__).parent / 'demo_results.json'
    with output_file.open('w') as f:
        json.dump(results_json, f, indent=2)

    print(f'\n=== Results saved to {output_file} ===\n')


if __name__ == '__main__':
    asyncio.run(main())
