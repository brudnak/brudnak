#!/bin/bash

# -----------------------------
# 📍 Code Location Tracker (Session-Based)
# -----------------------------
# Logs each coding session with full timestamp for future analysis (e.g. heatmaps)
# Replaces "count" model with per-session entries

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
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$CITY" ] || [ -z "$REGION" ] || [ -z "$COUNTRY" ]; then
  echo "❌ Could not fetch complete geolocation."
  exit 1
fi

# ------------------------------------------
# 2. Append new session to JSON log
# ------------------------------------------
LOG_FILE="location-log.json"
TABLE_FILE="table.md"
COUNTRY_NAMES_FILE="country-names.json"
COUNTRY_FLAGS_FILE="country-flags.json"

if [ ! -f "$LOG_FILE" ]; then
  echo "[]" > "$LOG_FILE"
fi

jq --arg ts "$TIMESTAMP" \
   --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" \
   --arg loc "$LOC" --arg org "$ORG" --arg tz "$TIMEZONE" \
   '. + [{"timestamp": $ts, "country": $c, "region": $r, "city": $city, "loc": $loc, "org": $org, "timezone": $tz}]' \
   "$LOG_FILE" > tmp.json && mv tmp.json "$LOG_FILE"

# ------------------------------------------
# 3. Generate Markdown Table
# ------------------------------------------
echo "<!-- log tracker start -->" > "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "## 🌍 Where I've Written Code" >> "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "| Country | Region / State | City | Sessions |" >> "$TABLE_FILE"
echo "|---------|-----------------|------|----------|" >> "$TABLE_FILE"

jq -c 'group_by(.country + .region + .city)
        | map({
            country: .[0].country,
            region: .[0].region,
            city: .[0].city,
            count: length
          })
        | .[]' "$LOG_FILE" | while read -r row; do
  COUNTRY=$(echo "$row" | jq -r '.country')
  REGION=$(echo "$row" | jq -r '.region')
  CITY=$(echo "$row" | jq -r '.city')
  COUNT=$(echo "$row" | jq -r '.count')
  EMOJI=$(jq -r --arg code "$COUNTRY" '.[$code] // ""' "$COUNTRY_FLAGS_FILE")
  NAME=$(jq -r --arg code "$COUNTRY" '.[$code] // $code' "$COUNTRY_NAMES_FILE")
  echo "| $EMOJI $NAME | $REGION | $CITY | $COUNT |" >> "$TABLE_FILE"
done

echo "" >> "$TABLE_FILE"
echo "<!-- log tracker end -->" >> "$TABLE_FILE"

# ------------------------------------------
# 4. Replace table in-place in README.md
# ------------------------------------------
awk '
  BEGIN {in_block=0}
  /<!-- log tracker start -->/ {
    print; 
    while ((getline line < "table.md") > 0) print line;
    in_block=1;
    next;
  }
  /<!-- log tracker end -->/ {in_block=0; next}
  !in_block {print}
' README.md > temp_readme.md

mv temp_readme.md README.md
rm "$TABLE_FILE"

# ------------------------------------------
# 5. Commit changes
# ------------------------------------------
git config --global user.name "LocationBot"
git config --global user.email "log@location.bot"
git add "$LOG_FILE" README.md

git diff --cached --quiet || git commit -m "📍 Updated code location log"
git push
