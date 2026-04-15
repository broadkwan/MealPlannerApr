#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/MealPlannerApp/MealPlannerApp/Resources/.env.supabase"

if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi

: "${SUPABASE_URL:?Set SUPABASE_URL in the environment or .env.supabase}"
: "${SUPABASE_SERVICE_ROLE_KEY:?Set SUPABASE_SERVICE_ROLE_KEY in the environment or .env.supabase}"

MENU_TABLE="${SUPABASE_MENU_TABLE:-menu_items}"
ASSIGNMENTS_TABLE="${SUPABASE_ASSIGNMENTS_TABLE:-daily_menu_assignments}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$ROOT_DIR/backups/$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

auth_header="apikey: $SUPABASE_SERVICE_ROLE_KEY"
bearer_header="Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"

fetch_table() {
  local table_name="$1"
  local output_file="$2"

  curl --fail --silent --show-error \
    "$SUPABASE_URL/rest/v1/$table_name?select=*" \
    -H "$auth_header" \
    -H "$bearer_header" \
    -H "Accept: application/json" \
    -H "Range: 0-999" \
    > "$output_file"
}

fetch_table "$MENU_TABLE" "$BACKUP_DIR/menu_items.json"
fetch_table "$ASSIGNMENTS_TABLE" "$BACKUP_DIR/daily_menu_assignments.json"

cat > "$BACKUP_DIR/README.txt" <<EOF
Supabase backup created at $TIMESTAMP
Menu table: $MENU_TABLE
Assignments table: $ASSIGNMENTS_TABLE
URL: $SUPABASE_URL
EOF

echo "Backup complete: $BACKUP_DIR"
