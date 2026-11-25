#!/usr/bin/env bash
# Applies the Supabase stub + all migrations to a scratch database and runs the RLS tests.
# Needs a local PostgreSQL 15+ (psql on PATH). Connection via standard PG* env vars.
set -euo pipefail
cd "$(dirname "$0")/.."
DB="${TEST_DB:-worklink_test}"
psql -v ON_ERROR_STOP=1 -q -d postgres -c "drop database if exists $DB" -c "create database $DB"
psql -v ON_ERROR_STOP=1 -q -d "$DB" -f tests/00_supabase_stub.sql
for f in migrations/*.sql; do
  echo "applying $f"
  psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$f"
done
psql -v ON_ERROR_STOP=1 -q -o /dev/null -d "$DB" -f tests/rls_test.sql
