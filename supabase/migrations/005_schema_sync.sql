-- ================================================================
-- 005: SCHEMA SYNC
-- Columns, policies and storage buckets that the Flutter app already
-- uses but were never captured in the earlier migrations. Needed to
-- bootstrap a fresh Supabase project. Safe to re-run (idempotent).
-- ================================================================

-- ---------------------------------------------------------------
-- MESSAGES: typed messages + location sharing
-- (used by SupabaseService.sendMessage / chat_detail.dart)
-- ---------------------------------------------------------------
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_lon DOUBLE PRECISION;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_name VARCHAR(255);
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS location_address VARCHAR(500);

-- ---------------------------------------------------------------
-- USERS: profile background picture (profile.dart / edit_profile_page.dart)
-- ---------------------------------------------------------------
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS background_picture_url TEXT;

-- ---------------------------------------------------------------
-- RLS gaps
-- ---------------------------------------------------------------

-- signUpWithEmail() upserts the profile row from the client
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- markMessagesAsRead() updates read_at on messages received by the user
DROP POLICY IF EXISTS "Swap participants can mark messages read" ON public.messages;
CREATE POLICY "Swap participants can mark messages read" ON public.messages
  FOR UPDATE
  USING (
    sender_user_id <> auth.uid() AND EXISTS (
      SELECT 1 FROM public.swaps s
      WHERE s.id = swap_id
        AND (s.user_a_id = auth.uid() OR s.user_b_id = auth.uid())
    )
  );

-- ---------------------------------------------------------------
-- STORAGE BUCKETS + POLICIES
-- ---------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) VALUES
  ('profile-pictures', 'profile-pictures', true),
  ('item-images', 'item-images', true),
  ('review-photos', 'review-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "TradeMatch public read" ON storage.objects;
CREATE POLICY "TradeMatch public read" ON storage.objects
  FOR SELECT
  USING (bucket_id IN ('profile-pictures', 'item-images', 'review-photos'));

DROP POLICY IF EXISTS "TradeMatch authenticated upload" ON storage.objects;
CREATE POLICY "TradeMatch authenticated upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('profile-pictures', 'item-images', 'review-photos'));

DROP POLICY IF EXISTS "TradeMatch owner update" ON storage.objects;
CREATE POLICY "TradeMatch owner update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id IN ('profile-pictures', 'item-images', 'review-photos') AND owner = auth.uid());

DROP POLICY IF EXISTS "TradeMatch owner delete" ON storage.objects;
CREATE POLICY "TradeMatch owner delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id IN ('profile-pictures', 'item-images', 'review-photos') AND owner = auth.uid());
