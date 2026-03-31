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
  v_user_id UUID := gen_random_uuid();
  v_email   TEXT := 'mazzda@gmail.com';
BEGIN
  -- If email already exists, just update the password and role then exit
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) THEN
    UPDATE auth.users
      SET encrypted_password = crypt('12345678', gen_salt('bf', 10)),
          updated_at          = NOW()
      WHERE email = v_email;
    UPDATE public.profiles
      SET role = 'admin', is_active = true, updated_at = NOW()
      WHERE email = v_email;
    RAISE NOTICE 'Admin user % already exists – password reset to 12345678.', v_email;
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
    crypt('12345678', gen_salt('bf', 10)),
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
  -- provider_id = email address for email/password auth (required in Supabase ≥ 2.x)
  INSERT INTO auth.identities (
    id,
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_email,
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
