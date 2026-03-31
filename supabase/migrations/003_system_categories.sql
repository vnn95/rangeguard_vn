-- ═══════════════════════════════════════════════════════════════════
-- Migration 003: System categories – Đơn vị (organizational units)
-- ═══════════════════════════════════════════════════════════════════

-- ── Units (Đơn vị) ────────────────────────────────────────────────────────────
-- Represents organizational units (Chi cục, Hạt kiểm lâm, Phòng ban, ...)
-- Distinct from stations (physical patrol posts)

CREATE TABLE IF NOT EXISTS units (
  id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name         TEXT        NOT NULL,
  code         TEXT,
  unit_type    TEXT        NOT NULL DEFAULT 'unit'
                           CHECK (unit_type IN ('department', 'division', 'unit', 'other')),
  province     TEXT,
  district     TEXT,
  commune      TEXT,       -- xã/phường
  address      TEXT,       -- địa chỉ chi tiết
  phone        TEXT,
  fax          TEXT,
  email        TEXT,
  website      TEXT,
  contact_person TEXT,     -- đầu mối liên hệ
  contact_phone  TEXT,
  contact_email  TEXT,
  parent_id    UUID        REFERENCES units(id) ON DELETE SET NULL,
  notes        TEXT,
  is_active    BOOLEAN     NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS units_province_idx ON units(province);
CREATE INDEX IF NOT EXISTS units_type_idx     ON units(unit_type);
CREATE INDEX IF NOT EXISTS units_parent_idx   ON units(parent_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_units_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_units_updated_at ON units;
CREATE TRIGGER trg_units_updated_at
  BEFORE UPDATE ON units
  FOR EACH ROW EXECUTE FUNCTION update_units_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE units ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read units
CREATE POLICY "units_select" ON units
  FOR SELECT TO authenticated USING (true);

-- Only admins can write
CREATE POLICY "units_insert" ON units
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "units_update" ON units
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "units_delete" ON units
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ── Seed: a few sample unit types ────────────────────────────────────────────
-- (Optional, can be removed in production)
INSERT INTO units (name, code, unit_type, province, phone, email) VALUES
  ('Chi cục Kiểm lâm tỉnh', 'CCKL', 'department', 'Tỉnh mẫu', NULL, NULL),
  ('Hạt Kiểm lâm Huyện 1',  'HKL-01', 'division', 'Tỉnh mẫu', NULL, NULL)
ON CONFLICT DO NOTHING;
