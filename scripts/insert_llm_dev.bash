SERVICE_URL=$(gcloud run services describe fermi-etl \
  --region=us-central1 \
  --format='value(status.url)')

curl -X POST $SERVICE_URL/insert_llm \
  -H "Content-Type: application/json" \
  -d '{"num_seeds": 40, "questions_per_seed": 2, "mode": "lru"}'
