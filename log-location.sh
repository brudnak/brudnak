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

# Insert new session
sqlite3 "$DB_FILE" <<EOF
INSERT INTO sessions (timestamp, country, region, city, loc, org, timezone) VALUES (
  '$TIMESTAMP', '$COUNTRY', '$REGION', '$CITY', '$LOC', '$ORG', '$TIMEZONE'
);
EOF

# Create a timestamped backup
BACKUP_PATH="$BACKUP_DIR/location-log-$TIMESTAMP.db"
cp "$DB_FILE" "$BACKUP_PATH"

# Keep only the 5 most recent backups
ls -tp $BACKUP_DIR/location-log-*.db | grep -v '/$' | tail -n +6 | xargs -I {} rm -- {}

# ------------------------------------------
# 3. Generate Markdown Table
# ------------------------------------------
echo "<!-- log tracker start -->" > "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "## 🌍 Where I've Written Code" >> "$TABLE_FILE"
echo "" >> "$TABLE_FILE"
echo "| Country | Region / State | City | Sessions |" >> "$TABLE_FILE"
echo "|---------|-----------------|------|----------|" >> "$TABLE_FILE"

sqlite3 -json "$DB_FILE" "
  SELECT country, region, city, COUNT(*) as count
  FROM sessions
  GROUP BY country, region, city
" | jq -c '.[]' | while read -r row; do
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
    in_block=1;
    while ((getline line < "table.md") > 0) print line;
    next;
  }
  /<!-- log tracker end -->/ {in_block=0; next}
  !in_block {print}
' README.md > temp_readme.md

mv temp_readme.md README.md
rm "$TABLE_FILE"

# ------------------------------------------
# 5. Commit changes as user
# ------------------------------------------
GIT_USER_NAME=$(git config --global user.name)
GIT_USER_EMAIL=$(git config --global user.email)

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git add "$DB_FILE" "$BACKUP_DIR" README.md

if ! git diff --cached --quiet; then
  git commit -m "📍 Updated code location log with rotated backup"
  git push
fi
