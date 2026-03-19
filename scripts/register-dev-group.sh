#!/bin/bash
# Register the cli:dev group for development/experimental sessions.
# Run once after the service has initialized the database.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="$PROJECT_ROOT/store/messages.db"

if [ ! -f "$DB" ]; then
  echo "Error: Database not found at $DB"
  echo "Run the service first to initialize the database."
  exit 1
fi

# Check if already registered
EXISTING=$(sqlite3 "$DB" "SELECT jid FROM registered_groups WHERE jid='cli:dev'" 2>/dev/null)
if [ -n "$EXISTING" ]; then
  echo "cli:dev group is already registered."
  exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

sqlite3 "$DB" "
  INSERT INTO registered_groups (jid, name, folder, trigger_pattern, added_at, requires_trigger, is_main)
  VALUES ('cli:dev', 'CLI Dev', 'dev', '@Andy', '$TIMESTAMP', 0, 0);
"

# Ensure the group folder exists
mkdir -p "$PROJECT_ROOT/groups/dev"

echo "Registered cli:dev group."
echo "Use: ./scripts/cli.sh cli:dev"
