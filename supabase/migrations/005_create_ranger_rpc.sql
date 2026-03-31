-- ═══════════════════════════════════════════════════════════════════
-- Migration 005: RPC function to create ranger accounts (admin only)
-- Called from Flutter via supabase.rpc('create_ranger_account', ...)
-- SECURITY DEFINER so it can write to auth.users from client context
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION create_ranger_account(
  p_email       TEXT,
  p_password    TEXT,
  p_full_name   TEXT,
  p_employee_id TEXT,
  p_unit        TEXT,
  p_role        TEXT    DEFAULT 'ranger',
  p_phone       TEXT    DEFAULT NULL,
  p_station_id  UUID    DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id     UUID := uuid_generate_v4();
  v_caller_role TEXT;
BEGIN
  -- ── 1. Only admins may call this function ───────────────────────
  SELECT role INTO v_caller_role
    FROM public.profiles
   WHERE id = auth.uid();

  IF v_caller_role IS DISTINCT FROM 'admin' THEN
    RAISE EXCEPTION 'Permission denied: only admins can create ranger accounts';
  END IF;

  -- ── 2. Validate role value ───────────────────────────────────────
  IF p_role NOT IN ('admin', 'leader', 'ranger', 'viewer') THEN
    RAISE EXCEPTION 'Invalid role: %', p_role;
  END IF;

  -- ── 3. Check email uniqueness ────────────────────────────────────
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = lower(p_email)) THEN
    RAISE EXCEPTION 'Email % is already registered', p_email;
  END IF;

  -- ── 4. Insert into auth.users ────────────────────────────────────
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    is_super_admin,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    lower(p_email),
    crypt(p_password, gen_salt('bf', 10)),
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

  -- ── 5. Insert into auth.identities ──────────────────────────────
  INSERT INTO auth.identities (
    id, provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    uuid_generate_v4(),
    lower(p_email),
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', lower(p_email)),
    'email',
    NOW(), NOW(), NOW()
  );

  -- ── 6. Upsert profile ────────────────────────────────────────────
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

-- Grant execute to authenticated users (RLS check is inside the function)
GRANT EXECUTE ON FUNCTION create_ranger_account TO authenticated;
