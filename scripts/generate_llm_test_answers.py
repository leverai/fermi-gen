#!/usr/bin/env python3
"""Generate sudo LLM answers for integration test data.

This script adds LLM answers to test_questions.json using simple fractions:
- gpt-5.1: 3/4 of correct answer
- gpt-5-mini: 1/2 of correct answer
- gpt-5-nano: 1/4 of correct answer
"""

import json
from pathlib import Path


def generate_llm_answers(test_data: dict) -> list[dict]:
    """Generate sudo LLM answers for all questions."""
    llm_answers = []

    # Model fractions (model_name: fraction)
    models = {
        'gpt-5.1': 3 / 4,
        'gpt-5-mini': 1 / 2,
        'gpt-5-nano': 1 / 4,
    }

    # Process each answer
    for answer in test_data['answers']:
        question_id = answer['question_id']
        correct_number = answer['number']
        correct_unit = answer['unit']

        # Generate LLM answer for each model
        for model_name, fraction in models.items():
            llm_answer = {
                'question_id': question_id,
                'model': model_name,
                'number': correct_number * fraction,
                'unit': correct_unit,
            }
            llm_answers.append(llm_answer)

    return llm_answers


def main() -> None:
    """Generate and add LLM answers to test_questions.json."""
    test_data_path = (
        Path(__file__).resolve().parents[1]
        / 'apps'
        / 'fermi-api'
        / 'tests'
        / 'data'
        / 'test_questions.json'
    )

    if not test_data_path.exists():
        print(f'❌ Test data file not found: {test_data_path}')
        return

    # Load existing test data
    print(f'📂 Loading test data from {test_data_path}...')
    with test_data_path.open() as f:
        test_data = json.load(f)

    # Check if llm_answers already exists
    if 'llm_answers' in test_data:
        print('⚠️  llm_answers already exists in test data. Regenerating...')

    # Generate LLM answers
    print(f'🤖 Generating LLM answers for {len(test_data["answers"])} questions...')
    llm_answers = generate_llm_answers(test_data)

    # Add to test data
    test_data['llm_answers'] = llm_answers

    # Write back to file
    print('💾 Writing updated test data...')
    with test_data_path.open('w') as f:
        json.dump(test_data, f, indent=4)

    models_count = len(llm_answers) // 3
    print(
        f'✅ Generated {len(llm_answers)} LLM answers '
        f'({models_count} questions x 3 models)',
    )


if __name__ == '__main__':
    main()
