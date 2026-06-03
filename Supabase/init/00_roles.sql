-- ============================================================
-- 00_roles.sql – Supabase belső szerepkörök létrehozása
-- Ezt az image már tartalmazza, de safeguardként itt is
-- ============================================================

DO $$
BEGIN
  -- anon role
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  -- authenticated role
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  -- service_role
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  -- authenticator (PostgREST kapcsolódik ezzel)
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'postgres';
  END IF;
  -- supabase_auth_admin (GoTrue)
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin NOINHERIT CREATEROLE LOGIN PASSWORD 'postgres';
  END IF;
  -- supabase_replication_admin (Realtime)
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase_replication_admin') THEN
    CREATE ROLE supabase_replication_admin LOGIN REPLICATION PASSWORD 'postgres';
  END IF;
  -- supabase (meta) – LOGIN szükséges a pg-meta kapcsolódáshoz
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supabase') THEN
    CREATE ROLE supabase LOGIN PASSWORD 'postgres';
  END IF;
END$$;

GRANT anon          TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role  TO authenticator;

-- supabase_auth_admin kap teljes jogot az auth és public sémán (GoTrue migrációkhoz)
-- A pop ORM a schema_migrations táblát a public sémában hozza létre
GRANT ALL ON SCHEMA auth   TO supabase_auth_admin;
GRANT ALL ON SCHEMA public TO supabase_auth_admin;

-- supabase_replication_admin kap jogot a _realtime sémán
CREATE SCHEMA IF NOT EXISTS _realtime;
GRANT ALL ON SCHEMA _realtime TO supabase_replication_admin;

-- supabase (pg-meta) kap olvasási jogot
GRANT USAGE ON SCHEMA public TO supabase;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO supabase;
GRANT USAGE ON SCHEMA auth TO supabase;
GRANT SELECT ON ALL TABLES IN SCHEMA auth TO supabase;
