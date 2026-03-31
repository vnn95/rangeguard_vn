-- ═══════════════════════════════════════════════════════════════════
-- Migration 004: Seed default admin account
-- Email   : admin@rangeguard.vn
-- Password: admin
-- Role    : admin
--
-- Run this ONCE on a fresh Supabase project.
-- After first login, change the password in Profile settings.
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_user_id UUID := uuid_generate_v4();
  v_email   TEXT := 'admin@rangeguard.vn';
BEGIN
  -- Skip if this email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) THEN
    RAISE NOTICE 'Admin user % already exists – skipping.', v_email;
    RETURN;
  END IF;

  -- ── 1. Create auth.users row ────────────────────────────────────
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    last_sign_in_at,
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
    v_email,
    -- bcrypt hash of 'admin' (cost=10)
    crypt('admin', gen_salt('bf', 10)),
    NOW(),          -- email already confirmed
    NOW(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object(
      'full_name',   'Quản trị viên',
      'employee_id', 'ADMIN-001',
      'unit',        'Ban Quản lý',
      'role',        'admin'
    ),
    false,
    NOW(),
    NOW(),
    '', '', '', ''
  );

  -- ── 2. Create identity (required for email/password login) ──────
  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    uuid_generate_v4(),
    v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email),
    'email',
    NOW(), NOW(), NOW()
  );

  -- ── 3. Create profile row ───────────────────────────────────────
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    employee_id,
    unit,
    role,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    v_email,
    'Quản trị viên',
    'ADMIN-001',
    'Ban Quản lý',
    'admin',
    true,
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    role       = 'admin',
    is_active  = true,
    updated_at = NOW();

  RAISE NOTICE 'Admin user created: % (id: %)', v_email, v_user_id;
END;
$$;
