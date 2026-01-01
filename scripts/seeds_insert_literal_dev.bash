SERVICE_URL=$(gcloud run services describe fermi-etl \
  --region=us-central1 \
  --format='value(status.url)')

# Insert Seeds
curl -X POST $SERVICE_URL/seeds/insert_literal \
  -H "Content-Type: application/json" \
  -d '{
        "seeds": [
            "TikTok", "Pizza", "Taylor Swift", "Coffee", "Emojis",
            "Cats", "iPhones", "Christmas", "Super Bowl", "Legos",
            "Spotify", "Airplanes", "YouTube", "Tacos", "Weddings",
            "Selfies", "Harry Potter", "Uber", "Sneakers", "Popcorn",
            "Netflix", "Dogs", "Coachella", "Chocolate", "Instagram",
            "Disneyland", "McDonald'\''s", "Fireworks", "Pokemon", "Amazon",
            "Halloween", "Sushi", "Video Games", "Toilet Paper", "NBA",
            "Ice Cream", "Balloons", "Marvel", "Star Wars", "Batteries",
            "Rubber Ducks", "Toothbrushes", "Donuts", "Skyscrapers", "Teabags",
            "K-Pop", "Pasta", "Avocados", "Headphones", "Bubble Tea"
        ]
      }'

# Insert manual questions
curl -X POST $SERVICE_URL/insert_literal \
  -H "Content-Type: application/json" \
  -d '{
        "questions": [
          x"How many Christmas trees are sold in the US each year?",
          x"How many ornaments are hanging on Christmas trees in the US on Christmas Eve?",
          "How many rolls of wrapping paper are used in the US each holiday season?",
          x"If you laid out all wrapping paper used in the US in December, how many football fields would it cover?",
          "How many gift tags are written in the US each holiday season?",
          "How many AA batteries are bought in the US in December?",
          "How many candy canes are eaten in the US each year?",
          "How many cups of hot chocolate are consumed in the US in December?",
          "How many gingerbread houses are built in the US each holiday season?",
          "How many ugly Christmas sweaters are worn in the US in December?",
          x"If you stacked all Christmas cards mailed in the US each year, how tall would the stack be?",
          "How many cookies are left out for Santa worldwide on Christmas Eve?",
          x"How many times is “Jingle Bells” played in the US in December?"
        ]
      }'

# Insert gemini flash answers
curl -X POST $SERVICE_URL/llm_answers/gemini-flash \
  -H "Content-Type: application/json" \
  -d '{
        "num_questions": 3
      }'

# Sync all
curl -X POST $SERVICE_URL/enrich/join_all \
  -H "Content-Type: application/json" \
  -d '{}'
