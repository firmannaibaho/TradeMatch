-- Add read_at column to messages table for tracking read status
-- Run this in Supabase SQL Editor

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Create index for faster unread message queries
CREATE INDEX IF NOT EXISTS idx_messages_read_at ON messages(read_at);
CREATE INDEX IF NOT EXISTS idx_messages_sender_user_id ON messages(sender_user_id);
