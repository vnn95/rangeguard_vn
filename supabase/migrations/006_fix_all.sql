-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 006: Comprehensive fix – extensions, RLS policies, RPC function
-- Run this ONCE in Supabase Dashboard → SQL Editor
-- Safe to re-run (fully idempotent)
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. EXTENSIONS ────────────────────────────────────────────────────────────
-- pgcrypto: required by create_ranger_account RPC (crypt / gen_salt)
-- Installed in `extensions` schema (Supabase default since 2023)
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- uuid-ossp is NOT needed – all tables use gen_random_uuid() (built-in PG 13+)

-- ── 2. HELPER FUNCTIONS (SECURITY DEFINER) ───────────────────────────────────
-- Using helper functions avoids two problems:
--   a) Infinite recursion: a policy on patrols that queries profiles would
--      trigger the profiles RLS, which may query back → deadlock.
--   b) Performance: subquery per row vs. one lookup per statement.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_leader_or_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'leader')
  );
$$;

-- ── 3. FIX RLS POLICIES ───────────────────────────────────────────────────────
-- Rules applied throughout:
--   • Replace deprecated `auth.role() = 'authenticated'` with `TO authenticated`
--   • Use helper functions instead of inline subqueries on profiles
--   • Separate SELECT policy from write policies (no `FOR ALL`)
--   • All policies are permissive (the default); deny-all is the RLS baseline

-- ─── profiles ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_select_all"     ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own"     ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own"     ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_service" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_all"      ON public.profiles;

-- Any authenticated user can read all profiles (needed for ranger lists etc.)
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT TO authenticated USING (true);

-- Users can only update their own profile; admins can update any
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id OR public.is_admin());

-- Normal signup path: user inserts their own profile row
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- service_role bypasses RLS entirely in Supabase, so no extra policy needed.
-- The handle_new_user() trigger runs as SECURITY DEFINER → also bypasses RLS.

-- ─── patrols ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "patrols_select_all"    ON public.patrols;
DROP POLICY IF EXISTS "patrols_insert_ranger" ON public.patrols;
DROP POLICY IF EXISTS "patrols_insert_auth"   ON public.patrols;
DROP POLICY IF EXISTS "patrols_update_own"    ON public.patrols;
DROP POLICY IF EXISTS "patrols_delete_admin"  ON public.patrols;

CREATE POLICY "patrols_select_all" ON public.patrols
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "patrols_insert_auth" ON public.patrols
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "patrols_update_own" ON public.patrols
  FOR UPDATE TO authenticated
  USING (auth.uid() = created_by OR public.is_leader_or_admin());

CREATE POLICY "patrols_delete_admin" ON public.patrols
  FOR DELETE TO authenticated USING (public.is_admin());

-- ─── waypoints ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "waypoints_select_all"  ON public.waypoints;
DROP POLICY IF EXISTS "waypoints_insert_all"  ON public.waypoints;
DROP POLICY IF EXISTS "waypoints_delete_admin" ON public.waypoints;

CREATE POLICY "waypoints_select_all" ON public.waypoints
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "waypoints_insert_all" ON public.waypoints
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "waypoints_delete_admin" ON public.waypoints
  FOR DELETE TO authenticated USING (public.is_admin());

-- ─── schedules ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "schedules_select_all"    ON public.schedules;
DROP POLICY IF EXISTS "schedules_insert_leader" ON public.schedules;
DROP POLICY IF EXISTS "schedules_update_leader" ON public.schedules;
DROP POLICY IF EXISTS "schedules_delete_admin"  ON public.schedules;

CREATE POLICY "schedules_select_all" ON public.schedules
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "schedules_insert_leader" ON public.schedules
  FOR INSERT TO authenticated WITH CHECK (public.is_leader_or_admin());

CREATE POLICY "schedules_update_leader" ON public.schedules
  FOR UPDATE TO authenticated
  USING (auth.uid() = created_by OR public.is_admin());

CREATE POLICY "schedules_delete_admin" ON public.schedules
  FOR DELETE TO authenticated USING (public.is_admin());

-- ─── stations ────────────────────────────────────────────────────────────────
-- Previous migration had `FOR ALL` which conflicts with the SELECT policy.
-- Replace with explicit per-operation policies.
DROP POLICY IF EXISTS "stations_select_all"    ON public.stations;
DROP POLICY IF EXISTS "stations_manage_admin"  ON public.stations;
DROP POLICY IF EXISTS "stations_insert_admin"  ON public.stations;
DROP POLICY IF EXISTS "stations_update_admin"  ON public.stations;
DROP POLICY IF EXISTS "stations_delete_admin"  ON public.stations;

CREATE POLICY "stations_select_all" ON public.stations
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "stations_insert_admin" ON public.stations
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "stations_update_admin" ON public.stations
  FOR UPDATE TO authenticated USING (public.is_admin());

CREATE POLICY "stations_delete_admin" ON public.stations
  FOR DELETE TO authenticated USING (public.is_admin());

-- ─── patrol_photos ───────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "photos_select_all"   ON public.patrol_photos;
DROP POLICY IF EXISTS "photos_insert_auth"  ON public.patrol_photos;
DROP POLICY IF EXISTS "photos_update_own"   ON public.patrol_photos;
DROP POLICY IF EXISTS "photos_delete_admin" ON public.patrol_photos;

CREATE POLICY "photos_select_all" ON public.patrol_photos
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "photos_insert_auth" ON public.patrol_photos
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "photos_update_own" ON public.patrol_photos
  FOR UPDATE TO authenticated
  USING (auth.uid() = uploaded_by OR public.is_leader_or_admin());

CREATE POLICY "photos_delete_admin" ON public.patrol_photos
  FOR DELETE TO authenticated USING (public.is_admin());

-- ─── units ───────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "units_select" ON public.units;
DROP POLICY IF EXISTS "units_insert" ON public.units;
DROP POLICY IF EXISTS "units_update" ON public.units;
DROP POLICY IF EXISTS "units_delete" ON public.units;

CREATE POLICY "units_select" ON public.units
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "units_insert" ON public.units
  FOR INSERT TO authenticated WITH CHECK (public.is_admin());

CREATE POLICY "units_update" ON public.units
  FOR UPDATE TO authenticated USING (public.is_admin());

CREATE POLICY "units_delete" ON public.units
  FOR DELETE TO authenticated USING (public.is_admin());

-- ── 4. FIX handle_new_user TRIGGER ───────────────────────────────────────────
-- Already correct in migration 002, but re-apply here to be safe.
-- Key points:
--   • SECURITY DEFINER + SET search_path = public → bypasses RLS on profiles
--   • Inner BEGIN/EXCEPTION block → never blocks user creation on failure

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  BEGIN
    INSERT INTO public.profiles (
      id, email, full_name, employee_id, unit, role, is_active, created_at
    ) VALUES (
      NEW.id,
      COALESCE(NEW.email, ''),
      COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
      COALESCE(NEW.raw_user_meta_data->>'employee_id', ''),
      COALESCE(NEW.raw_user_meta_data->>'unit', ''),
      COALESCE(NEW.raw_user_meta_data->>'role', 'ranger'),
      true,
      NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
      email      = EXCLUDED.email,
      full_name  = CASE WHEN profiles.full_name = ''
                        THEN EXCLUDED.full_name
                        ELSE profiles.full_name END,
      updated_at = NOW();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[RangerGuard] handle_new_user failed for %: %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 5. FIX create_ranger_account RPC ─────────────────────────────────────────
-- Root cause of gen_salt error:
--   SET search_path = public  →  pgcrypto lives in `extensions` schema
--   →  crypt() / gen_salt() not found
-- Fix: set search_path to include `extensions` schema

CREATE OR REPLACE FUNCTION public.create_ranger_account(
  p_email       TEXT,
  p_password    TEXT,
  p_full_name   TEXT,
  p_employee_id TEXT,
  p_unit        TEXT,
  p_role        TEXT  DEFAULT 'ranger',
  p_phone       TEXT  DEFAULT NULL,
  p_station_id  UUID  DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = extensions, public, auth   -- extensions first → finds crypt/gen_salt
AS $$
DECLARE
  v_user_id     UUID := gen_random_uuid();
  v_caller_role TEXT;
BEGIN
  -- 1. Only admins may call this function
  SELECT role INTO v_caller_role
    FROM public.profiles
   WHERE id = auth.uid();

  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Permission denied: only admins can create ranger accounts';
  END IF;

  -- 2. Validate role
  IF p_role NOT IN ('admin', 'leader', 'ranger', 'viewer') THEN
    RAISE EXCEPTION 'Invalid role: %', p_role;
  END IF;

  -- 3. Check email uniqueness
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = lower(p_email)) THEN
    RAISE EXCEPTION 'Email % đã được đăng ký', p_email;
  END IF;

  -- 4. Insert into auth.users
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    lower(p_email),
    extensions.crypt(p_password, extensions.gen_salt('bf', 10)),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object(
      'full_name',   p_full_name,
      'employee_id', p_employee_id,
      'unit',        p_unit,
      'role',        p_role
    ),
    false,
    NOW(), NOW(),
    '', '', '', ''
  );

  -- 5. Insert into auth.identities (required for email/password login in Supabase v2)
  INSERT INTO auth.identities (
    id, provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    gen_random_uuid(),
    lower(p_email),
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', lower(p_email)),
    'email',
    NOW(), NOW(), NOW()
  );

  -- 6. Upsert profile (handle_new_user trigger fires too, so use ON CONFLICT)
  INSERT INTO public.profiles (
    id, email, full_name, employee_id, unit, role,
    phone, station_id, is_active, created_at, updated_at
  ) VALUES (
    v_user_id, lower(p_email), p_full_name, p_employee_id,
    p_unit, p_role, p_phone, p_station_id,
    true, NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email       = EXCLUDED.email,
    full_name   = EXCLUDED.full_name,
    employee_id = EXCLUDED.employee_id,
    unit        = EXCLUDED.unit,
    role        = EXCLUDED.role,
    phone       = EXCLUDED.phone,
    station_id  = EXCLUDED.station_id,
    updated_at  = NOW();

  RETURN v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_ranger_account TO authenticated;

-- ── 6. SCHEMA PERMISSIONS (ensure Supabase roles can access all tables) ───────
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL   ON ALL TABLES    IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL   ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL   ON ALL ROUTINES  IN SCHEMA public TO anon, authenticated, service_role;
