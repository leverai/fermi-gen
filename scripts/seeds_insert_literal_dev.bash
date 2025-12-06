SERVICE_URL=$(gcloud run services describe fermi-etl \
  --region=us-central1 \
  --format='value(status.url)')

curl -X POST $SERVICE_URL/seeds/insert_literal \
  -H "Content-Type: application/json" \
  -d '{
        "seeds": [
            "Global pizza consumption and toppings habits",
            "Commercial aviation flights and passenger volume",
            "The scale of the Solar System and planetary sizes",
            "LEGO brick production and global distribution",
            "Smartphone screen time and app usage habits",
            "Human heartbeats, blinking, and biological rhythms",
            "Movie franchise box office revenues and runtimes",
            "Ant populations vs. human biomass",
            "Spotify streaming numbers and music popularity",
            "Ocean depths and deep-sea pressure",
            "Coffee vs. tea drinking cultures globally",
            "Skyscrapers, elevators, and vertical architecture",
            "Social media influencers and follower engagement rates",
            "Dog and cat pet ownership statistics",
            "The speed of sound vs. the speed of light",
            "Fast food franchise locations and logistics",
            "Daily water usage in modern households",
            "Wikipedia article counts and language distribution",
            "Electric vehicles vs. internal combustion engines",
            "Blue whales and marine megafauna sizes",
            "Olympic records in running and swimming",
            "YouTube video upload rates and viewership",
            "Global shipping containers and cargo logistics",
            "Human sleep patterns and dreaming duration",
            "Distance to the Moon and satellite orbits",
            "Grocery store inventory and product variety",
            "Super Bowl vs. World Cup viewership numbers",
            "Rain, clouds, and precipitation volume",
            "Video game sales and hours played",
            "Plastic bottle production and recycling rates",
            "Roller coaster heights, speeds, and g-forces",
            "Email and text message daily volume",
            "Bird migration distances and flight speeds",
            "Emoji usage frequency and digital communication",
            "The weight and value of gold reserves",
            "Subway systems and urban commuter volume",
            "Hair and nail growth rates",
            "Crowd sizes",
            "Sugar content in popular treats and beverages",
            "Famous Bridges, tunnels, and infrastructure lengths"
        ]
      }'
