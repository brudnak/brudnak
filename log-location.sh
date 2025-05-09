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

if [ ! -f "$LOG_FILE" ]; then
  echo "[]" > "$LOG_FILE"
fi

jq --arg ts "$TIMESTAMP" \
   --arg c "$COUNTRY" --arg r "$REGION" --arg city "$CITY" \
   --arg loc "$LOC" --arg org "$ORG" --arg tz "$TIMEZONE" \
   '. + [{"timestamp": $ts, "country": $c, "region": $r, "city": $city, "loc": $loc, "org": $org, "timezone": $tz}]' \
   "$LOG_FILE" > tmp.json && mv tmp.json "$LOG_FILE"

# Function to convert country code to emoji flag
country_flag() {
  local code="$1"
  for (( i=0; i<${#code}; i++ )); do
    printf "\U$(printf '%x' $((0x1F1E6 + $(printf '%d' "'${code:$i:1}" ) - 65)))"
  done
}

# ------------------------------------------
# 3. Generate Markdown Table
# ------------------------------------------
echo "<!-- log tracker start -->" > "$TABLE_FILE"
echo "## 🌍 Where I've Written Code" >> "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "| Country | Region / State | City | Sessions |" >> "$TABLE_FILE"
echo "|---------|-----------------|------|----------|" >> "$TABLE_FILE"

jq -r 'group_by(.country + .region + .city) 
        | map({key: "\(.[] | .country),\(.[] | .region),\(.[] | .city)", count: length}) 
        | .[]' "$LOG_FILE" | while IFS=, read -r line; do
  COUNTRY=$(echo "$line" | cut -d '|' -f 1 | xargs)
  REGION=$(echo "$line" | cut -d '|' -f 2 | xargs)
  CITY=$(echo "$line" | cut -d '|' -f 3 | xargs)
  COUNT=$(echo "$line" | cut -d '|' -f 4 | xargs)
  EMOJI=$(country_flag "$COUNTRY")
  NAME=$(jq -r --arg code "$COUNTRY" '.[$code] // $code' "$COUNTRY_NAMES_FILE")
  echo "| $EMOJI $NAME | $REGION | $CITY | $COUNT |" >> "$TABLE_FILE"
done

echo "<!-- log tracker end -->" >> "$TABLE_FILE"

# ------------------------------------------
# 4. Replace content between log tracker tags in-place
# ------------------------------------------
awk -v newblock="$(cat $TABLE_FILE | sed 's/\//\\\//g' | tr '\n' '\\n')" '
BEGIN { inblock=0 }
{
  if ($0 ~ /<!-- log tracker start -->/) {
    print "<!-- log tracker start -->";
    print "";
    inblock=1;
    while (getline < "table.md") print;
    next
  }
  if ($0 ~ /<!-- log tracker end -->/) {
    inblock=0;
    next
  }
  if (!inblock) print
}' README.md > new_readme.md

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
