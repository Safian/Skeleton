-- Set passwords for pre-existing Supabase roles
-- The roles themselves are created by the supabase/postgres image
\set pgpass `echo "$POSTGRES_PASSWORD"`

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    EXECUTE 'ALTER USER authenticator WITH PASSWORD ' || quote_literal(:'pgpass');
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    EXECUTE 'ALTER USER supabase_auth_admin WITH PASSWORD ' || quote_literal(:'pgpass');
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    EXECUTE 'ALTER USER supabase_storage_admin WITH PASSWORD ' || quote_literal(:'pgpass');
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    EXECUTE 'ALTER USER supabase_functions_admin WITH PASSWORD ' || quote_literal(:'pgpass');
  END IF;
END $$;

-- Transfer auth function ownership to supabase_auth_admin
-- so GoTrue can CREATE OR REPLACE them during its migration
DO $$
DECLARE
  func record;
BEGIN
  FOR func IN
    SELECT p.oid, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'auth'
  LOOP
    EXECUTE format('ALTER FUNCTION auth.%I(%s) OWNER TO supabase_auth_admin',
      func.proname,
      pg_get_function_identity_arguments(func.oid));
  END LOOP;
END$$;

ALTER SCHEMA auth OWNER TO supabase_auth_admin;

-- Ensure graphql_public and pg_graphql exist so PostgREST can start correctly
CREATE SCHEMA IF NOT EXISTS graphql_public;
CREATE EXTENSION IF NOT EXISTS pg_graphql;
