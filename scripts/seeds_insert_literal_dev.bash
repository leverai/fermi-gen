SERVICE_URL=$(gcloud run services describe fermi-etl \
  --region=us-central1 \
  --format='value(status.url)')

# Insert Seeds
curl -X POST $SERVICE_URL/seeds/insert_literal \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
        "seeds": [
            "Cul-de-sacs", "Suburbs", "Gated communities", "HOAs", "Neighbors", "Roommates",
            "Landlords", "Tenants", "Leases", "Mortgages", "Real estate", "Open houses",
            "Moving trucks", "Packing peanuts", "Bubble wrap", "Cardboard forts"
        ]
      }'

# Insert manual questions
curl -X POST $SERVICE_URL/insert_literal \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
        "questions": [
          "In a year, how many times does the average American driver go over the speed limit?",
          "How heavy is the average cow in the US?",
          "How many times does the average person blink in a day?"
        ],
        "provider": "human"
      }'

# Run pipeline from LLM questions
curl -X POST $SERVICE_URL/insert_llm \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
        "num_seeds": 100,
        "questions_per_seed": 2,
        "mode": "lru"
      }'

# Insert gemini flash answers
curl -X POST $SERVICE_URL/llm_answers/gemini-flash \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
        "num_questions": 3
      }'

# Sync all
curl -X POST $SERVICE_URL/enrich/join_all \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{}'
