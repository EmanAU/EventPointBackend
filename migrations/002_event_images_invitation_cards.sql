-- Event gallery images (multiple images per event)
CREATE TABLE IF NOT EXISTS event_images (
    image_id SERIAL PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_images_event ON event_images(event_id);

-- Invitation card (one per event, customizable content)
CREATE TABLE IF NOT EXISTS invitation_cards (
    event_id UUID PRIMARY KEY REFERENCES events(event_id) ON DELETE CASCADE,
    headline TEXT DEFAULT 'TOGETHER WITH THEIR FAMILIES',
    couple_names TEXT DEFAULT '',
    invitation_text TEXT DEFAULT 'INVITE YOU TO CELEBRATE THEIR WEDDING',
    event_date TEXT DEFAULT '',
    event_time TEXT DEFAULT '',
    description TEXT DEFAULT '',
    address TEXT DEFAULT '',
    template_id INT DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
