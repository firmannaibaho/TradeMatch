-- ================================================================
-- BARTERSWAP: SUPABASE MIGRATION
-- Complete PostgreSQL Schema + RLS Policies
-- Generated: 2025-12-17
-- ================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- TABLE DEFINITIONS
-- ================================================================

-- USERS (synced with auth.users)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  google_id TEXT UNIQUE,
  phone TEXT,
  profile_picture_url TEXT,
  default_location_city TEXT,
  default_lat DOUBLE PRECISION,
  default_lon DOUBLE PRECISION,
  rating DECIMAL(3,2) DEFAULT 0.00,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- CATEGORIES
CREATE TABLE public.categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  icon TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed categories
INSERT INTO categories (name, icon) VALUES
  ('Electronics', 'laptop'),
  ('Fashion', 'shirt'),
  ('Home & Garden', 'home'),
  ('Sports', 'football'),
  ('Books', 'book'),
  ('Games', 'gamepad'),
  ('Collectibles', 'star'),
  ('Other', 'cube');

-- ITEMS
CREATE TABLE public.items (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id BIGINT REFERENCES categories(id),
  title VARCHAR(100) NOT NULL,
  description VARCHAR(2000),
  condition TEXT CHECK (condition IN ('new', 'like_new', 'good', 'fair', 'poor')),
  estimated_value DECIMAL(12,2),
  currency VARCHAR(3) DEFAULT 'IDR',
  location_city TEXT,
  location_lat DOUBLE PRECISION,
  location_lon DOUBLE PRECISION,
  wants_description TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available', 'in_trade', 'traded', 'removed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_items_user_id ON items(user_id);
CREATE INDEX idx_items_category_id ON items(category_id);
CREATE INDEX idx_items_status ON items(status);

-- ITEM_IMAGES
CREATE TABLE public.item_images (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  item_id BIGINT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_item_images_item_id ON item_images(item_id);

-- ITEM_WANTS
CREATE TABLE public.item_wants (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  item_id BIGINT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  category_id BIGINT NOT NULL REFERENCES categories(id)
);

-- SWIPES
CREATE TABLE public.swipes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  swiper_user_id UUID NOT NULL REFERENCES users(id),
  swiper_item_id BIGINT NOT NULL REFERENCES items(id),
  swiped_on_item_id BIGINT NOT NULL REFERENCES items(id),
  action TEXT NOT NULL CHECK (action IN ('like', 'skip')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(swiper_item_id, swiped_on_item_id)
);

CREATE INDEX idx_swipes_swiper_item ON swipes(swiper_item_id);
CREATE INDEX idx_swipes_swiped_on_item ON swipes(swiped_on_item_id);

-- SWAPS
CREATE TABLE public.swaps (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_a_id UUID REFERENCES users(id),
  user_b_id UUID REFERENCES users(id),
  item_a_id BIGINT NOT NULL REFERENCES items(id),
  item_b_id BIGINT NOT NULL REFERENCES items(id),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'location_suggested', 'location_agreed', 'trade_complete', 'cancelled')),
  item_a_owner_confirmed BOOLEAN DEFAULT FALSE,
  item_b_owner_confirmed BOOLEAN DEFAULT FALSE,
  suggested_location_lat DOUBLE PRECISION,
  suggested_location_lon DOUBLE PRECISION,
  suggested_location_name VARCHAR(255),
  suggested_location_address VARCHAR(500),
  location_suggested_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(item_a_id, item_b_id)
);

-- MESSAGES
CREATE TABLE public.messages (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  swap_id BIGINT NOT NULL REFERENCES swaps(id) ON DELETE CASCADE,
  sender_user_id UUID NOT NULL REFERENCES users(id),
  message_text VARCHAR(1000) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_swap_id ON messages(swap_id);

-- REVIEWS
CREATE TABLE public.reviews (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  swap_id BIGINT NOT NULL REFERENCES swaps(id),
  reviewer_user_id UUID NOT NULL REFERENCES users(id),
  reviewed_user_id UUID NOT NULL REFERENCES users(id),
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment VARCHAR(500),
  photos JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(swap_id, reviewer_user_id)
);

-- NOTIFICATIONS
CREATE TABLE public.notifications (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);

-- ================================================================
-- TRIGGERS & FUNCTIONS
-- ================================================================

-- Auto-create user profile on auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-set user IDs from items when swap is created
CREATE OR REPLACE FUNCTION set_swap_users()
RETURNS TRIGGER AS $$
BEGIN
  SELECT user_id INTO NEW.user_a_id FROM items WHERE id = NEW.item_a_id;
  SELECT user_id INTO NEW.user_b_id FROM items WHERE id = NEW.item_b_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_swap_insert
  BEFORE INSERT ON swaps
  FOR EACH ROW EXECUTE FUNCTION set_swap_users();

-- Auto-complete trade when both confirm
CREATE OR REPLACE FUNCTION check_trade_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.item_a_owner_confirmed = TRUE AND NEW.item_b_owner_confirmed = TRUE THEN
    NEW.status := 'trade_complete';
    NEW.updated_at := NOW();
    UPDATE items SET status = 'traded' WHERE id IN (NEW.item_a_id, NEW.item_b_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_swap_update
  BEFORE UPDATE ON swaps
  FOR EACH ROW EXECUTE FUNCTION check_trade_completion();

-- Auto-update user rating average
CREATE OR REPLACE FUNCTION update_user_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE users 
  SET rating = (SELECT COALESCE(AVG(rating), 0) FROM reviews WHERE reviewed_user_id = NEW.reviewed_user_id)
  WHERE id = NEW.reviewed_user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_review_insert
  AFTER INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_user_rating();

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_items_updated_at BEFORE UPDATE ON items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_swaps_updated_at BEFORE UPDATE ON swaps FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ================================================================
-- ROW LEVEL SECURITY POLICIES
-- ================================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_wants ENABLE ROW LEVEL SECURITY;
ALTER TABLE swipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE swaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- USERS
CREATE POLICY "Anyone can view user profiles" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

-- CATEGORIES (public read)
CREATE POLICY "Anyone can view categories" ON categories FOR SELECT USING (true);

-- ITEMS
CREATE POLICY "Anyone can view available items" ON items FOR SELECT 
  USING (status = 'available' OR user_id = auth.uid());
CREATE POLICY "Authenticated users can create items" ON items FOR INSERT 
  WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());
CREATE POLICY "Users can update own items" ON items FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own items" ON items FOR DELETE USING (user_id = auth.uid());

-- ITEM_IMAGES
CREATE POLICY "Anyone can view item images" ON item_images FOR SELECT USING (true);
CREATE POLICY "Item owners can insert images" ON item_images FOR INSERT 
  WITH CHECK (EXISTS (SELECT 1 FROM items WHERE items.id = item_id AND items.user_id = auth.uid()));
CREATE POLICY "Item owners can delete images" ON item_images FOR DELETE 
  USING (EXISTS (SELECT 1 FROM items WHERE items.id = item_id AND items.user_id = auth.uid()));

-- ITEM_WANTS
CREATE POLICY "Anyone can view item wants" ON item_wants FOR SELECT USING (true);
CREATE POLICY "Item owners can manage wants" ON item_wants FOR ALL 
  USING (EXISTS (SELECT 1 FROM items WHERE items.id = item_id AND items.user_id = auth.uid()));

-- SWIPES
CREATE POLICY "Users can view own swipes" ON swipes FOR SELECT USING (swiper_user_id = auth.uid());
CREATE POLICY "Authenticated users can create swipes" ON swipes FOR INSERT WITH CHECK (swiper_user_id = auth.uid());

-- SWAPS
CREATE POLICY "Swap participants can view" ON swaps FOR SELECT 
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());
CREATE POLICY "Swap participants can update" ON swaps FOR UPDATE 
  USING (user_a_id = auth.uid() OR user_b_id = auth.uid());

-- MESSAGES
CREATE POLICY "Swap participants can view messages" ON messages FOR SELECT 
  USING (EXISTS (
    SELECT 1 FROM swaps WHERE swaps.id = swap_id 
    AND (swaps.user_a_id = auth.uid() OR swaps.user_b_id = auth.uid())
  ));
CREATE POLICY "Swap participants can send messages" ON messages FOR INSERT 
  WITH CHECK (sender_user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM swaps WHERE swaps.id = swap_id 
    AND (swaps.user_a_id = auth.uid() OR swaps.user_b_id = auth.uid())
  ));

-- REVIEWS
CREATE POLICY "Anyone can view reviews" ON reviews FOR SELECT USING (true);
CREATE POLICY "Swap participants can create reviews" ON reviews FOR INSERT 
  WITH CHECK (
    reviewer_user_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM swaps WHERE swaps.id = swap_id 
      AND swaps.status = 'trade_complete'
      AND (swaps.user_a_id = auth.uid() OR swaps.user_b_id = auth.uid())
    )
  );

-- NOTIFICATIONS
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (user_id = auth.uid());

-- ================================================================
-- ENABLE REALTIME
-- ================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE swaps;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ================================================================
-- STORAGE BUCKETS (run in Supabase Dashboard or via API)
-- ================================================================
-- INSERT INTO storage.buckets (id, name, public) VALUES ('profile-pictures', 'profile-pictures', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('item-images', 'item-images', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('review-photos', 'review-photos', true);
