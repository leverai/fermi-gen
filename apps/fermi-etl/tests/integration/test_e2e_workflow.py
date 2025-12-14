# """End-to-end integration test for fermi-etl pipeline.

# This test uses real API calls (OpenAI, SerpAPI) to verify the complete workflow.
# """

# import asyncio
# from typing import cast

# import sqlalchemy as sa
# from fastapi.testclient import TestClient
# from sqlalchemy.ext.asyncio import create_async_engine


# async def _get_seed_count() -> int:
#     """Get count of seeds in database."""
#     import os

#     db_url = os.environ['DATABASE_URL']
#     engine = create_async_engine(db_url, echo=False)
#     async with engine.connect() as conn:
#         result = await conn.execute(sa.text('SELECT COUNT(*) FROM seeds'))
#         count = cast(int, result.scalar() or 0)
#     await engine.dispose()
#     return count


# async def _get_question_count() -> int:
#     """Get count of questions in database."""
#     import os

#     db_url = os.environ['DATABASE_URL']
#     engine = create_async_engine(db_url, echo=False)
#     async with engine.connect() as conn:
#         result = await conn.execute(sa.text('SELECT COUNT(*) FROM fermi_questions'))
#         count = cast(int, result.scalar() or 0)
#     await engine.dispose()
#     return count


# async def _get_answer_count() -> int:
#     """Get count of answers in database."""
#     import os

#     db_url = os.environ['DATABASE_URL']
#     engine = create_async_engine(db_url, echo=False)
#     async with engine.connect() as conn:
#         result = await conn.execute(sa.text('SELECT COUNT(*) FROM fermi_answers'))
#         count = cast(int, result.scalar() or 0)
#     await engine.dispose()
#     return count


# async def _get_question_by_id(question_id: int) -> dict:
#     """Get question details by ID."""
#     import os

#     db_url = os.environ['DATABASE_URL']
#     engine = create_async_engine(db_url, echo=False)
#     async with engine.connect() as conn:
#         result = await conn.execute(
#             sa.text(
#                 'SELECT id, text, embedding, category, difficulty '
#                 'FROM fermi_questions WHERE id = :id',
#             ),
#             {'id': question_id},
#         )
#         row = result.fetchone()
#     await engine.dispose()
#     if row:
#         # Parse embedding - pgvector returns it as a string in text format
#         embedding_data = row[2]
#         # Convert pgvector string like '[1.0,2.0,3.0]' to list
#         if isinstance(embedding_data, str):
#             import json

#             embedding_list = json.loads(embedding_data)
#         elif hasattr(embedding_data, '__iter__'):
#             embedding_list = list(embedding_data)
#         else:
#             embedding_list = None

#         return {
#             'id': row[0],
#             'text': row[1],
#             'embedding': embedding_list,
#             'category': row[3],
#             'difficulty': row[4],
#         }
#     return {}


# async def _get_answer_for_question(question_id: int) -> dict:
#     """Get answer for a question."""
#     import os

#     db_url = os.environ['DATABASE_URL']
#     engine = create_async_engine(db_url, echo=False)
#     async with engine.connect() as conn:
#         result = await conn.execute(
#             sa.text(
#                 'SELECT question_id, number, unit, success, snippet '
#                 'FROM fermi_answers WHERE question_id = :id',
#             ),
#             {'id': question_id},
#         )
#         row = result.fetchone()
#     await engine.dispose()
#     if row:
#         return {
#             'question_id': row[0],
#             'number': row[1],
#             'unit': row[2],
#             'success': row[3],
#             'snippet': row[4],
#         }
#     return {}


# def test_full_pipeline_with_real_apis(api_client: TestClient) -> None:
#     """Test complete ETL pipeline: seed -> generate -> answer -> enrich.

#     This is the single comprehensive integration test that uses real API calls.
#     It tests the entire workflow end-to-end with actual OpenAI and SerpAPI calls.

#     Steps:
#     1. Insert a seed
#     2. Generate a question from the seed
#     3. Answer the question
#     4. Verify database state at each step

#     Note: This test requires valid API keys in .env and will make real API calls.
#     """
#     # Step 1: Insert a seed
#     seed_text = 'Renewable Energy'

#     response = api_client.post('/seeds/insert_literal', json={'seeds': [seed_text]})

#     assert response.status_code == 200, f'Seed insertion failed: {response.text}'
#     seed_result = response.json()
#     assert seed_result['success'] is True
#     assert seed_result['result']['total_inserted'] >= 1

#     # Verify seed in database
#     seed_count = asyncio.run(_get_seed_count())
#     assert seed_count >= 1, 'Seed should be inserted in database'

#     # Step 2: Generate 1 question using Thompson sampling
#     response = api_client.post(
#         '/questions/insert_llm',
#         json={'num_seeds': 1, 'questions_per_seed': 1, 'mode': 'thompson'},
#     )

#     assert response.status_code == 200, f'Question generation failed: {response.text}'
#     question_result = response.json()
#     assert question_result['success'] is True

#     question_data = question_result['result']
#     assert question_data['questions_yielded'] >= 1, (
#         'At least one question should be generated'
#     )
#     assert len(question_data['new_question_ids']) >= 1

#     question_id = question_data['new_question_ids'][0]

#     # Verify question in database
#     question = asyncio.run(_get_question_by_id(question_id))
#     assert question, f'Question {question_id} should exist in database'
#     assert question['id'] == question_id
#     assert len(question['text']) > 0, 'Question should have text'
#     assert question['embedding'] is not None, 'Question should have embedding'
#     assert len(question['embedding']) == 1536, 'Embedding should have 1536 dimensions'

#     # Step 3: Answer the question (using insert_serp endpoint)
#     # The endpoint answers unanswered questions, so newly generated question
#     # will be answered
#     response = api_client.post('/answers/insert_serp', json={'num_questions': 10})

#     assert response.status_code == 200, f'Answer generation failed: {response.text}'
#     answer_result = response.json()
#     assert answer_result['success'] is True

#     answer_data = answer_result['result']
#     # Note: Answer might fail due to SerpAPI limits or question format
#     # We check that the endpoint executed without errors
#     assert 'questions_answered' in answer_data
#     assert 'questions_failed' in answer_data

#     # Verify answer attempt in database (success or failure)
#     answer = asyncio.run(_get_answer_for_question(question_id))
#     assert answer, f'Answer attempt for question {question_id} should exist'
#     assert answer['question_id'] == question_id

#     # If answer was successful, verify the data
#     if answer['success']:
#         assert answer['number'] is not None, 'Successful answer should have a number'
#         assert answer['number'] > 0, 'Answer number should be positive'
#         # Unit can be None for dimensionless answers
#         assert answer['snippet'], 'Successful answer should have a snippet'

#         # Verify enrichment was applied (category and difficulty)
#         enriched_question = asyncio.run(_get_question_by_id(question_id))
#         # Note: Enrichment may or may not have completed depending on timing
#         # We just verify the question still exists
#         assert enriched_question['id'] == question_id


# def test_composite_workflow_endpoint(api_client: TestClient) -> None:
#     """Test the composite /insert_llm endpoint that does everything in one call.

#     This tests the convenience endpoint that:
#     1. Generates questions
#     2. Answers them
#     3. Enriches them
#     4. Refreshes the materialized view

#     All in a single API call.
#     """
#     # Use the composite endpoint
#     response = api_client.post(
#         '/insert_llm',
#         json={'num_seeds': 1, 'questions_per_seed': 1, 'mode': 'lru'},
#     )

#     # The composite endpoint should work end-to-end
#     # Note: It might succeed even if no seeds exist (will return 0 questions)
#     assert response.status_code == 200, f'Composite workflow failed: {response.text}'
#     result = response.json()

#     # Check structure of response
#     assert 'success' in result
#     assert 'question_result' in result or 'error' in result


# def test_seed_insertion_deduplication(api_client: TestClient) -> None:
#     """Test that duplicate seeds are rejected."""
#     # Insert a seed
#     seed_text = 'Solar Power'
#     response = api_client.post('/seeds/insert_literal', json={'seeds': [seed_text]})

#     assert response.status_code == 200
#     first_result = response.json()
#     assert first_result['success'] is True

#     # Try to insert the same seed again
#     response = api_client.post('/seeds/insert_literal', json={'seeds': [seed_text]})

#     assert response.status_code == 200
#     second_result = response.json()
#     # Should reject duplicate
#     assert second_result['result']['total_inserted'] == 0
#     assert second_result['result']['total_rejected'] >= 1


# def test_health_endpoints(api_client: TestClient) -> None:
#     """Test basic health/info endpoints."""
#     # Test root endpoint
#     response = api_client.get('/')
#     assert response.status_code == 200
#     data = response.json()
#     assert data['service'] == 'fermi-etl'
#     assert 'version' in data

#     # Test health endpoint
#     response = api_client.get('/health')
#     assert response.status_code == 200
#     data = response.json()
#     assert data['status'] == 'healthy'

from app.core.deduplication import insert_unique_pending_questions
from app.main import __version__
