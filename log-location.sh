#!/bin/bash

# -----------------------------
# 📍 Code Location Tracker (SQLite-based with rotating backups)
# -----------------------------
# Logs each coding session into an SQLite database for better query and aggregation support

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
# 2. Setup SQLite DB and insert session
# ------------------------------------------
DB_FILE="location-log.db"
BACKUP_DIR="backups"
TABLE_FILE="table.md"
COUNTRY_NAMES_FILE="country-names.json"
COUNTRY_FLAGS_FILE="country-flags.json"

mkdir -p "$BACKUP_DIR"

# Create table if it doesn't exist
sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS sessions (
  timestamp TEXT,
  country TEXT,
  region TEXT,
  city TEXT,
  loc TEXT,
  org TEXT,
  timezone TEXT
);
EOF

# Escape special characters for SQLite
CITY_ESC=$(echo "$CITY" | sed "s/'/''/g")
REGION_ESC=$(echo "$REGION" | sed "s/'/''/g")
ORG_ESC=$(echo "$ORG" | sed "s/'/''/g")
TIMEZONE_ESC=$(echo "$TIMEZONE" | sed "s/'/''/g")

# Insert new session with proper escaping
sqlite3 "$DB_FILE" <<EOF
INSERT INTO sessions (timestamp, country, region, city, loc, org, timezone) VALUES (
  '$TIMESTAMP', '$COUNTRY', '$REGION_ESC', '$CITY_ESC', '$LOC', '$ORG_ESC', '$TIMEZONE_ESC'
);
EOF

# Create a timestamped backup
BACKUP_PATH="$BACKUP_DIR/location-log-$TIMESTAMP.db"
cp "$DB_FILE" "$BACKUP_PATH"

# Keep only the 5 most recent backups
find "$BACKUP_DIR" -name "location-log-*.db" -type f -printf "%T@ %p\n" | sort -nr | tail -n +6 | cut -d' ' -f2- | xargs -r rm

# ------------------------------------------
# 3. Generate Markdown Table
# ------------------------------------------
echo "<!-- log tracker start -->" > "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "## 🗺️ Global Commits" >> "$TABLE_FILE"
echo "![Auto Updated](https://img.shields.io/badge/Generated%20by-GitHub%20Actions-blue?logo=githubactions)" >> "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "| Country | Region / State | City | Sessions |" >> "$TABLE_FILE"
echo "|---------|-----------------|------|----------|" >> "$TABLE_FILE"

# Check if country files exist before using them
if [ ! -f "$COUNTRY_NAMES_FILE" ]; then
  echo "⚠️ Warning: $COUNTRY_NAMES_FILE not found. Using country codes instead."
fi

if [ ! -f "$COUNTRY_FLAGS_FILE" ]; then
  echo "⚠️ Warning: $COUNTRY_FLAGS_FILE not found. No flags will be displayed."
fi

# Use temporary file for safer SQL execution
sqlite3 -json "$DB_FILE" "
  SELECT country, region, city, COUNT(*) as count
  FROM sessions
  GROUP BY country, region, city
" > sessions_temp.json

# Process the JSON safely
cat sessions_temp.json | jq -c '.[]' | while read -r row; do
  COUNTRY=$(echo "$row" | jq -r '.country')
  REGION=$(echo "$row" | jq -r '.region')
  CITY=$(echo "$row" | jq -r '.city')
  COUNT=$(echo "$row" | jq -r '.count')
  
  # Handle missing country files gracefully
  if [ -f "$COUNTRY_FLAGS_FILE" ]; then
    EMOJI=$(jq -r --arg code "$COUNTRY" '.[$code] // ""' "$COUNTRY_FLAGS_FILE")
  else
    EMOJI=""
  fi
  
  if [ -f "$COUNTRY_NAMES_FILE" ]; then
    NAME=$(jq -r --arg code "$COUNTRY" '.[$code] // $code' "$COUNTRY_NAMES_FILE")
  else
    NAME="$COUNTRY"
  fi
  
  echo "| $EMOJI $NAME | $REGION | $CITY | $COUNT |" >> "$TABLE_FILE"
done

# Clean up temp file
rm -f sessions_temp.json

echo "" >> "$TABLE_FILE"
echo "<!-- log tracker end -->" >> "$TABLE_FILE"

# ------------------------------------------
# 4. Replace table in-place in README.md
# ------------------------------------------
# Check if README.md exists
if [ ! -f "README.md" ]; then
  echo "⚠️ Warning: README.md not found. Creating a new one."
  cp "$TABLE_FILE" "README.md"
else
  # Use a safer temp file approach with unique name
  TEMP_README=$(mktemp)
  
  awk '
    BEGIN {in_block=0}
    /<!-- log tracker start -->/ {
      in_block=1;
      while ((getline line < "'"$TABLE_FILE"'") > 0) print line;
      next;
    }
    /<!-- log tracker end -->/ {in_block=0; next}
    !in_block {print}
  ' README.md > "$TEMP_README"
  
  # Only replace if the operation succeeded
  if [ $? -eq 0 ]; then
    mv "$TEMP_README" README.md
  else
    echo "❌ Error updating README.md"
    rm -f "$TEMP_README"
    exit 1
  fi
fi

rm -f "$TABLE_FILE"

# ------------------------------------------
# 5. Commit changes
# ------------------------------------------
# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ Not in a git repository. Cannot commit changes."
  exit 1
fi

# Add files with checks
if [ -f "$DB_FILE" ]; then
  git add "$DB_FILE"
else
  echo "⚠️ Warning: $DB_FILE not found for git add"
fi

if [ -d "$BACKUP_DIR" ]; then
  git add "$BACKUP_DIR"
else
  echo "⚠️ Warning: $BACKUP_DIR not found for git add"
fi

if [ -f "README.md" ]; then
  git add README.md
else
  echo "⚠️ Warning: README.md not found for git add"
fi

# Only commit if there are changes
if ! git diff --cached --quiet; then
  git commit -m "📍 Updated code location log with rotated backup"
  git push
  echo "✅ Successfully updated and pushed location log"
else
  echo "ℹ️ No changes to commit"
fi