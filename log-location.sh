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
echo "## 🌍 Where I've Written Code" >> "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "| Country | Region / State | City | Sessions |" >> "$TABLE_FILE"
echo "|---------|-----------------|------|----------|" >> "$TABLE_FILE"

jq -r 'group_by(.country + .region + .city) 
        | map({key: "\(.[] | .country),\(.[] | .region),\(.[] | .city)", count: length}) 
        | .[] 
        | "| \(.key | split(",") | .[0]) | \(.key | split(",") | .[1]) | \(.key | split(",") | .[2]) | \(.count) |"' "$LOG_FILE" >> "$TABLE_FILE"

echo "<!-- log tracker end -->" >> "$TABLE_FILE"

# ------------------------------------------
# 4. Inject between log tracker tags in README
# ------------------------------------------
sed -i.bak -e '/<!-- log tracker start -->/,/<!-- log tracker end -->/d' README.md
awk '{print} /<!-- log tracker start -->/ {exit}' "$TABLE_FILE" > temp_top.md
awk 'BEGIN{found=0} {if($0 ~ /<!-- log tracker end -->/) found=1; if(found) print}' "$TABLE_FILE" > temp_bottom.md
awk 'FNR==NR { print; next } 1' temp_top.md temp_bottom.md > temp_combined.md
awk '1' README.md temp_combined.md > new_readme.md
mv new_readme.md README.md
rm "$TABLE_FILE" temp_top.md temp_bottom.md README.md.bak

# ------------------------------------------
# 5. Commit changes
# ------------------------------------------
git config --global user.name "LocationBot"
git config --global user.email "log@location.bot"
git add "$LOG_FILE" README.md

git diff --cached --quiet || git commit -m "📍 Updated code location log"
git push
