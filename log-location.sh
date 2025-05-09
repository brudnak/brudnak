#!/bin/bash

# -----------------------------
# 📍 Code Location Tracker (Enhanced)
# -----------------------------
# Logs your geolocation metadata (excluding IP) to your GitHub repo
# Designed to run from a self-hosted GitHub Actions runner

set -e

# ------------------------------------------
# 1. Get geolocation data from ipinfo.io
# ------------------------------------------
GEO=$(curl -s "https://ipinfo.io?token=$IPINFO_TOKEN")

CITY=$(echo "$GEO" | jq -r '.city')
REGION=$(echo "$GEO" | jq -r '.region')
COUNTRY=$(echo "$GEO" | jq -r '.country')
LOC=$(echo "$GEO" | jq -r '.loc')
ORG=$(echo "$GEO" | jq -r '.org')
TIMEZONE=$(echo "$GEO" | jq -r '.timezone')
DATE=$(date +"%Y-%m-%d")

if [ -z "$CITY" ] || [ -z "$REGION" ] || [ -z "$COUNTRY" ]; then
  echo "❌ Could not fetch complete geolocation."
  exit 1
fi

# ------------------------------------------
# 2. Prepare data structure
# ------------------------------------------
LOG_FILE="location-log.json"
TABLE_FILE="table.md"

# Create JSON log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
  echo "[]" > "$LOG_FILE"
fi

# Check for existing location
if jq -e --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" '
  map(select(.country == $c and .region == $r and .city == $city)) | length > 0
' "$LOG_FILE" > /dev/null; then
  # Update count
  jq --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" '
    map(if .country == $c and .region == $r and .city == $city
        then .count += 1 else . end)
  ' "$LOG_FILE" > tmp.json && mv tmp.json "$LOG_FILE"
else
  # Add new entry
  jq --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" \
     --arg date "$DATE" --arg loc "$LOC" --arg org "$ORG" --arg tz "$TIMEZONE" '
    . + [{"country": $c, "region": $r, "city": $city, "date": $date, "loc": $loc, "org": $org, "timezone": $tz, "count": 1}]
  ' "$LOG_FILE" > tmp.json && mv tmp.json "$LOG_FILE"
fi

# ------------------------------------------
# 3. Generate Markdown Table
# ------------------------------------------
echo "## 🌍 Where I've Written Code" > "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "| Country | Region / State | City | Times |" >> "$TABLE_FILE"
echo "|---------|-----------------|------|-------|" >> "$TABLE_FILE"

jq -r '.[] | "| \(.country) | \(.region) | \(.city) | \(.count) |"' "$LOG_FILE" >> "$TABLE_FILE"

# ------------------------------------------
# 4. Inject into README
# ------------------------------------------
awk "
  BEGIN {p=1}
  /^## 🌍 Where I've Written Code/ {print; p=0; next}
  /^## / && !p {p=1}
  p
" README.md > new_readme.md
cat "$TABLE_FILE" >> new_readme.md
mv new_readme.md README.md
rm "$TABLE_FILE"

# ------------------------------------------
# 5. Commit changes
# ------------------------------------------
git config --global user.name "LocationBot"
git config --global user.email "log@location.bot"
git add "$LOG_FILE" README.md

git diff --cached --quiet || git commit -m "📍 Updated code location log"
git push
