-- ═══════════════════════════════════════════════════════════════════════════
-- Migration 007: Fix photo_gallery view + create Storage buckets
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Fix photo_gallery view ─────────────────────────────────────────────
-- Original view had ORDER BY inside it, which PostgREST dislikes.
-- Remove ORDER BY here; the app applies .order() via PostgREST query.

CREATE OR REPLACE VIEW public.photo_gallery AS
SELECT
  pp.id,
  pp.patrol_id,
  pp.waypoint_id,
  pp.storage_path,
  pp.original_url,
  pp.thumbnail_url,
  pp.taken_at,
  pp.latitude,
  pp.longitude,
  pp.observation_type,
  pp.notes,
  pp.tags,
  pp.file_size_bytes,
  pp.uploaded_by,
  pp.created_at,
  p.patrol_id   AS patrol_code,
  p.leader_name,
  p.station_name,
  p.start_time  AS patrol_date
FROM public.patrol_photos pp
JOIN public.patrols p ON p.id = pp.patrol_id;

-- Grant access to the view
GRANT SELECT ON public.photo_gallery TO authenticated, anon;

-- ── 2. Storage buckets ────────────────────────────────────────────────────
-- patrol-photos: stores photos uploaded from device or decoded from SMART
-- avatars:       user profile pictures
-- Must run as service_role or owner. If you see "already exists" – that's fine.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('patrol-photos', 'patrol-photos', false, 52428800,  -- 50 MB limit
   ARRAY['image/jpeg','image/png','image/webp','image/heic']),
  ('avatars',       'avatars',       true,  5242880,   -- 5 MB limit
   ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;

-- ── 3. Storage RLS policies ───────────────────────────────────────────────

-- patrol-photos: authenticated can read; owner can upload/delete
CREATE POLICY "patrol_photos_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'patrol-photos');

CREATE POLICY "patrol_photos_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'patrol-photos');

CREATE POLICY "patrol_photos_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'patrol-photos' AND
    (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin())
  );

-- avatars: public read; owner write
CREATE POLICY "avatars_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'avatars');

CREATE POLICY "avatars_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "avatars_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
