-- Add event_cover_image_url to events table
-- Run this once: psql -d your_db -f add_event_cover_image.sql
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_cover_image_url TEXT DEFAULT '';
