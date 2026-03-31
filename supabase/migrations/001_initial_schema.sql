-- ═══════════════════════════════════════════════════════════════════
-- RangerGuard VN - Supabase Schema Migration
-- Version: 1.0.0
-- Description: Initial database schema with PostGIS support
-- ═══════════════════════════════════════════════════════════════════

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Profiles (extends Supabase auth.users) ───────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT NOT NULL DEFAULT '',
  employee_id TEXT NOT NULL DEFAULT '',
  unit TEXT NOT NULL DEFAULT '',
  phone TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'ranger'
    CHECK (role IN ('admin', 'leader', 'ranger', 'viewer')),
  station_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Stations (Trạm kiểm lâm) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT,
  location GEOMETRY(POINT, 4326),
  province TEXT,
  district TEXT,
  address TEXT,
  phone TEXT,
  manager_id UUID REFERENCES profiles(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Patrols (Chuyến tuần tra) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patrols (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patrol_id TEXT NOT NULL,               -- SMART patrol ID
  leader_id UUID REFERENCES profiles(id),
  leader_name TEXT NOT NULL DEFAULT '',
  station_id UUID REFERENCES stations(id),
  station_name TEXT NOT NULL DEFAULT '',
  transport_type TEXT NOT NULL DEFAULT 'Đi bộ',
  mandate TEXT NOT NULL DEFAULT '',
  comments TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  total_distance_meters DOUBLE PRECISION DEFAULT 0,
  total_waypoints INTEGER DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed'
    CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
  -- PostGIS track geometry (LineString)
  track_geometry GEOMETRY(LINESTRING, 4326),
  -- Computed columns
  duration_minutes INTEGER GENERATED ALWAYS AS (
    CASE WHEN end_time IS NOT NULL
    THEN EXTRACT(EPOCH FROM (end_time - start_time))::INTEGER / 60
    ELSE NULL END
  ) STORED,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Waypoints (Điểm GPS) ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS waypoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patrol_id UUID NOT NULL REFERENCES patrols(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  altitude DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  bearing DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  observation_type TEXT NOT NULL DEFAULT 'Waypoint',
  photo_url TEXT,
  notes TEXT,
  timestamp TIMESTAMPTZ NOT NULL,
  -- PostGIS point geometry
  location GEOMETRY(POINT, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)
  ) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Schedules (Lịch tuần tra) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  scheduled_date TIMESTAMPTZ NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  leader_id UUID REFERENCES profiles(id),
  leader_name TEXT NOT NULL DEFAULT '',
  ranger_ids UUID[] DEFAULT '{}',
  ranger_names TEXT[] DEFAULT '{}',
  station_id UUID REFERENCES stations(id),
  station_name TEXT NOT NULL DEFAULT '',
  -- Patrol area polygon
  area_polygon GEOMETRY(POLYGON, 4326),
  mandate TEXT,
  status TEXT NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned', 'ongoing', 'completed', 'cancelled')),
  linked_patrol_id UUID REFERENCES patrols(id),
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Mandates (Mệnh lệnh / Nhiệm vụ) ────────────────────────────────
CREATE TABLE IF NOT EXISTS mandates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════
-- Indexes for performance
-- ═══════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_patrols_leader ON patrols(leader_id);
CREATE INDEX IF NOT EXISTS idx_patrols_start_time ON patrols(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_patrols_status ON patrols(status);
CREATE INDEX IF NOT EXISTS idx_patrols_station ON patrols(station_id);
CREATE INDEX IF NOT EXISTS idx_patrols_track_geom ON patrols USING GIST(track_geometry);

CREATE INDEX IF NOT EXISTS idx_waypoints_patrol ON waypoints(patrol_id);
CREATE INDEX IF NOT EXISTS idx_waypoints_timestamp ON waypoints(timestamp);
CREATE INDEX IF NOT EXISTS idx_waypoints_location ON waypoints USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_waypoints_obs_type ON waypoints(observation_type);

CREATE INDEX IF NOT EXISTS idx_schedules_date ON schedules(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_schedules_leader ON schedules(leader_id);
CREATE INDEX IF NOT EXISTS idx_schedules_status ON schedules(status);

-- ═══════════════════════════════════════════════════════════════════
-- Row Level Security (RLS) Policies
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE patrols ENABLE ROW LEVEL SECURITY;
ALTER TABLE waypoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE stations ENABLE ROW LEVEL SECURITY;

-- Profiles: users can see all, only update their own
CREATE POLICY "profiles_select_all" ON profiles
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Patrols: all authenticated users can read, rangers can create/update theirs
CREATE POLICY "patrols_select_all" ON patrols
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "patrols_insert_ranger" ON patrols
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "patrols_update_own" ON patrols
  FOR UPDATE USING (
    auth.uid() = created_by OR
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'leader')
    )
  );

CREATE POLICY "patrols_delete_admin" ON patrols
  FOR DELETE USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin')
  );

-- Waypoints: same as patrols
CREATE POLICY "waypoints_select_all" ON waypoints
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "waypoints_insert_all" ON waypoints
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Schedules: all can read, leaders+ can create
CREATE POLICY "schedules_select_all" ON schedules
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "schedules_insert_leader" ON schedules
  FOR INSERT WITH CHECK (
    auth.uid() IN (
      SELECT id FROM profiles WHERE role IN ('admin', 'leader')
    )
  );

CREATE POLICY "schedules_update_leader" ON schedules
  FOR UPDATE USING (
    auth.uid() = created_by OR
    auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin')
  );

-- Stations: all can read
CREATE POLICY "stations_select_all" ON stations
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "stations_manage_admin" ON stations
  FOR ALL USING (
    auth.uid() IN (SELECT id FROM profiles WHERE role = 'admin')
  );

-- ═══════════════════════════════════════════════════════════════════
-- Triggers
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_patrols_updated_at
  BEFORE UPDATE ON patrols
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_schedules_updated_at
  BEFORE UPDATE ON schedules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create profile on user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, employee_id, unit, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'employee_id', ''),
    COALESCE(NEW.raw_user_meta_data->>'unit', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'ranger')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ═══════════════════════════════════════════════════════════════════
-- Useful views
-- ═══════════════════════════════════════════════════════════════════

-- Patrol summary with stats
CREATE OR REPLACE VIEW patrol_summary AS
SELECT
  p.*,
  COUNT(w.id) AS waypoint_count,
  MIN(w.timestamp) AS first_waypoint,
  MAX(w.timestamp) AS last_waypoint,
  ST_Length(p.track_geometry::geography) AS calculated_distance_meters
FROM patrols p
LEFT JOIN waypoints w ON w.patrol_id = p.id
GROUP BY p.id;

-- Monthly stats view
CREATE OR REPLACE VIEW monthly_patrol_stats AS
SELECT
  DATE_TRUNC('month', start_time) AS month,
  COUNT(*) AS patrol_count,
  COUNT(DISTINCT leader_id) AS ranger_count,
  SUM(total_distance_meters) AS total_distance,
  AVG(duration_minutes) AS avg_duration_minutes
FROM patrols
WHERE status = 'completed'
GROUP BY DATE_TRUNC('month', start_time)
ORDER BY month DESC;

-- ═══════════════════════════════════════════════════════════════════
-- Seed data: Sample stations and mandates
-- ═══════════════════════════════════════════════════════════════════

INSERT INTO stations (name, code, province, district) VALUES
  ('Trạm Kiểm Lâm Số 1', 'TKL-01', 'Quảng Nam', 'Tây Giang'),
  ('Trạm Kiểm Lâm Số 2', 'TKL-02', 'Quảng Nam', 'Đông Giang'),
  ('Trạm Kiểm Lâm Số 3', 'TKL-03', 'Thừa Thiên Huế', 'A Lưới'),
  ('Trạm Trung Tâm', 'TKL-TT', 'Đà Nẵng', 'Hòa Vang')
ON CONFLICT DO NOTHING;

INSERT INTO mandates (name, code, description) VALUES
  ('Tuần tra định kỳ', 'TTDK', 'Tuần tra bảo vệ rừng theo lịch định kỳ'),
  ('Chống phá rừng', 'CPR', 'Tuần tra phát hiện và ngăn chặn hành vi phá rừng'),
  ('Kiểm tra bẫy thú', 'KTBT', 'Phát hiện và tháo gỡ bẫy thú trái phép'),
  ('Phòng cháy rừng', 'PCR', 'Tuần tra phòng chống cháy rừng'),
  ('Giám sát đa dạng sinh học', 'GDSH', 'Theo dõi và ghi nhận đa dạng sinh học')
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- Storage buckets (run via Supabase Dashboard or CLI)
-- ═══════════════════════════════════════════════════════════════════
-- INSERT INTO storage.buckets (id, name, public) VALUES
--   ('avatars', 'avatars', true),
--   ('patrol-photos', 'patrol-photos', false);
