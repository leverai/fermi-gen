SERVICE_URL=$(gcloud run services describe fermi-etl \
  --region=us-central1 \
  --format='value(status.url)')

# Insert Seeds
curl -X POST $SERVICE_URL/seeds/insert_literal \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
        "seeds": [
          "Plastic Forks", "Paper Straws", "Napkins", "Coasters", "Chopsticks", "Takeout Boxes",
          "Soy Sauce Packets", "Fortune Cookies", "Pizza Boxes", "Nachos", "Burritos", "Pop-Tarts",
          "Marshmallows", "Jolly Ranchers", "Tic Tacs", "M&Ms", "Skittles", "Goldfish Crackers",
          "Beef Jerky", "String Cheese", "Hot Sauce", "Energy Bars", "Granola Bars", "Trail Mix",
          "Mosquito Bites", "Sunburns", "Tan Lines", "Band-Aids", "Q-Tips", "Cotton Balls", "Floss",
          "Mouthwash", "Deodorant", "Razors", "Nail Clippers", "Hair Ties", "Hair Dryers", "Straighteners",
          "Sunscreen", "Bug Spray", "Hand Sanitizer", "Thermometers", "Bathroom Scales", "Dumbbells",
          "Yoga Mats", "Treadmills", "Jump Ropes", "Hula Hoops", "Frisbees", "Boomerangs", "Kites",
          "Ping Pong Balls", "Golf Tees", "Whistles", "Medals", "Trophies", "Participation Awards"
        ]
      }'

# Insert manual questions
curl -X POST $SERVICE_URL/insert_literal \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  -H "Content-Type: application/json" \
  -d '{
        "questions": [
          "How many Christmas trees are sold in the US each year?",
          "How many ornaments are hanging on Christmas trees in the US on Christmas Eve?",
          "How many rolls of wrapping paper are used in the US each holiday season?",
          "If you laid out all wrapping paper used in the US in December, how many football fields would it cover?",
          "How many gift tags are written in the US each holiday season?",
          "How many AA batteries are bought in the US in December?",
          "How many candy canes are eaten in the US each year?",
          "How many cups of hot chocolate are consumed in the US in December?",
          "How many gingerbread houses are built in the US each holiday season?",
          "How many ugly Christmas sweaters are worn in the US in December?",
          "If you stacked all Christmas cards mailed in the US each year, how tall would the stack be?",
          "How many cookies are left out for Santa worldwide on Christmas Eve?",
          "How many times is “Jingle Bells” played in the US in December?"
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
