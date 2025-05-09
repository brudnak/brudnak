#!/bin/bash

set -e

IP=$(curl -s ifconfig.me)
GEO=$(curl -s "https://ipinfo.io/$IP?token=$IPINFO_TOKEN")

COUNTRY=$(echo "$GEO" | jq -r '.country')
REGION=$(echo "$GEO" | jq -r '.region')
CITY=$(echo "$GEO" | jq -r '.city')
DATE=$(date +%Y-%m-%d)

if [ -z "$COUNTRY" ] || [ -z "$REGION" ]; then
  echo "❌ Could not fetch geolocation."
  exit 1
fi

echo "📍 Location: $CITY, $REGION, $COUNTRY on $DATE"

# Create file if it doesn't exist
touch location-log.json
if [ ! -s location-log.json ]; then
  echo "[]" > location-log.json
fi

# Check for existing entry
if jq -e --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" '
  map(select(.country == $c and .region == $r and .city == $city)) | length > 0
' location-log.json > /dev/null; then
  # Update count
  jq --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" '
    map(if .country == $c and .region == $r and .city == $city
        then .count += 1 else . end)
  ' location-log.json > tmp.json && mv tmp.json location-log.json
else
  # Add new location
  jq --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" --arg date "$DATE" '
    . + [{"country": $c, "region": $r, "city": $city, "date": $date, "count": 1}]
  ' location-log.json > tmp.json && mv tmp.json location-log.json
fi

# Generate Markdown Table
echo "## 🌍 Where I've Written Code" > table.md
echo -e "| Country | Region / State | City | Times |\n|---------|-----------------|------|-------|" >> table.md

jq -r '.[] | "| \(.country) | \(.region) | \(.city) | \(.count) |"' location-log.json >> table.md

# Inject into README.md
awk '/## 🌍 Where I'"'"'ve Written Code/ {exit} 1' README.md > new_readme.md
cat table.md >> new_readme.md
mv new_readme.md README.md
