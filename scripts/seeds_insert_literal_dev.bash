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
            "How many Christmas trees are sold in the US each year?",
            "How many ornaments are hanging on Christmas trees in the US on Christmas Eve?",
            "If you laid out all wrapping paper used in the US in December, how many football fields would it cover?",
            "If you stacked all Christmas cards mailed in the US each year, how tall would the stack be?",
            "How many times is “Jingle Bells” played in the US in December?"
        ]
      }'