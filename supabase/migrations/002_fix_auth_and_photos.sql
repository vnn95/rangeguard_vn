-- ═══════════════════════════════════════════════════════════════════
-- Migration 002: Fix auth trigger + Add photos table
-- ═══════════════════════════════════════════════════════════════════

-- ── FIX 1: Make trigger fault-tolerant (fixes "Database error saving new user") ──
-- The trigger must NOT throw exceptions or Supabase Auth rolls back user creation

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
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
      email = EXCLUDED.email,
      full_name = CASE WHEN profiles.full_name = '' THEN EXCLUDED.full_name ELSE profiles.full_name END,
      updated_at = NOW();
  EXCEPTION WHEN OTHERS THEN
    -- Never block user creation - just log warning
    RAISE WARNING '[RangerGuard] handle_new_user failed for %: %', NEW.id, SQLERRM;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ── FIX 2: Ensure profiles table has correct permissions ──
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- ── ADD: patrol_photos table (separate from waypoints for easier querying) ──
CREATE TABLE IF NOT EXISTS patrol_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patrol_id UUID NOT NULL REFERENCES patrols(id) ON DELETE CASCADE,
  waypoint_id UUID REFERENCES waypoints(id) ON DELETE SET NULL,
  -- Storage
  storage_path TEXT,           -- path in Supabase Storage
  original_url TEXT,           -- original URL from SMART JSON
  thumbnail_url TEXT,
  -- Metadata
  taken_at TIMESTAMPTZ,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  observation_type TEXT DEFAULT 'Photo',
  notes TEXT,
  -- Tags for search
  tags TEXT[] DEFAULT '{}',
  -- File info
  file_size_bytes INTEGER,
  width INTEGER,
  height INTEGER,
  -- Relations
  uploaded_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_photos_patrol ON patrol_photos(patrol_id);
CREATE INDEX IF NOT EXISTS idx_photos_taken_at ON patrol_photos(taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_photos_obs_type ON patrol_photos(observation_type);
CREATE INDEX IF NOT EXISTS idx_photos_location ON patrol_photos USING GIST(
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- RLS for photos
ALTER TABLE patrol_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "photos_select_all" ON patrol_photos
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "photos_insert_auth" ON patrol_photos
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "photos_update_own" ON patrol_photos
  FOR UPDATE USING (
    auth.uid() = uploaded_by OR
    auth.uid() IN (SELECT id FROM profiles WHERE role IN ('admin', 'leader'))
  );

CREATE POLICY "photos_delete_admin" ON patrol_photos
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin')
  );

-- ── VIEW: photos with patrol info for easy querying ──
CREATE OR REPLACE VIEW photo_gallery AS
SELECT
  pp.*,
  p.patrol_id AS patrol_code,
  p.leader_name,
  p.station_name,
  p.start_time AS patrol_date
FROM patrol_photos pp
JOIN patrols p ON p.id = pp.patrol_id
ORDER BY pp.taken_at DESC;

-- ── FUNCTION: Get patrol import summary ──
CREATE OR REPLACE FUNCTION get_patrol_report(p_patrol_id UUID)
RETURNS TABLE (
  total_waypoints BIGINT,
  total_photos BIGINT,
  total_threats BIGINT,
  total_animals BIGINT,
  distance_km NUMERIC,
  duration_minutes INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(w.id) AS total_waypoints,
    COUNT(pp.id) AS total_photos,
    COUNT(w.id) FILTER (WHERE w.observation_type = 'Threat') AS total_threats,
    COUNT(w.id) FILTER (WHERE w.observation_type = 'Animal') AS total_animals,
    ROUND((p.total_distance_meters / 1000)::NUMERIC, 2) AS distance_km,
    p.duration_minutes
  FROM patrols p
  LEFT JOIN waypoints w ON w.patrol_id = p.id
  LEFT JOIN patrol_photos pp ON pp.patrol_id = p.id
  WHERE p.id = p_patrol_id
  GROUP BY p.id;
END;
$$ LANGUAGE plpgsql;

-- ── INDEX: Full-text search on waypoint notes ──
ALTER TABLE waypoints ADD COLUMN IF NOT EXISTS notes_tsv tsvector
  GENERATED ALWAYS AS (to_tsvector('simple', COALESCE(notes, ''))) STORED;

CREATE INDEX IF NOT EXISTS idx_waypoints_notes_fts ON waypoints USING GIN(notes_tsv);
