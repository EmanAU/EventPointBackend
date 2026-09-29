-- Fix: Return EventId as TEXT so Dapper can map to string (avoids "Error parsing column 0 - Guid")
-- Drop all event_create overloads so only the TEXT-returning one exists

DROP FUNCTION IF EXISTS event_create(INT, TEXT, TEXT, TIMESTAMP, TEXT, TEXT, TEXT, INT, INT, TEXT);
DROP FUNCTION IF EXISTS event_create(INT, VARCHAR, UUID, TIMESTAMPTZ, VARCHAR, TEXT, TEXT, INT, INT, VARCHAR);

CREATE OR REPLACE FUNCTION event_create(
    p_event_category_id INT,
    p_event_title TEXT,
    p_creator_id TEXT,
    p_event_date_time TIMESTAMP,
    p_venue TEXT DEFAULT '',
    p_event_cover_image_url TEXT DEFAULT '',
    p_tag_line TEXT DEFAULT '',
    p_expected_guest_number INT DEFAULT 0,
    p_sub_category_id INT DEFAULT NULL,
    p_location TEXT DEFAULT ''
)
RETURNS TABLE ("EventId" TEXT, "AdminCode" TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id UUID;
    v_admin_code VARCHAR;
    v_event_code VARCHAR;
    v_creator_uuid UUID;
BEGIN
    IF TRIM(p_event_title) = '' THEN
        RAISE EXCEPTION 'Event title cannot be empty' USING ERRCODE = 'P0001';
    END IF;

    v_creator_uuid := p_creator_id::UUID;

    v_admin_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 8));
    v_event_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    INSERT INTO events (
        event_category_id, event_title, creator_id, event_date_time,
        venue, event_cover_image_url, tag_line, expected_guest_number,
        sub_category_id, location, admin_code, event_code
    )
    VALUES (
        p_event_category_id, p_event_title, v_creator_uuid, p_event_date_time::TIMESTAMPTZ,
        COALESCE(p_venue, ''), COALESCE(p_event_cover_image_url, ''),
        COALESCE(p_tag_line, ''), COALESCE(p_expected_guest_number, 0),
        p_sub_category_id, COALESCE(p_location, ''),
        v_admin_code, v_event_code
    )
    RETURNING events.event_id INTO v_event_id;

    INSERT INTO event_members (event_id, user_id, role)
    VALUES (v_event_id, v_creator_uuid, 'Admin');

    RETURN QUERY SELECT v_event_id::TEXT, v_admin_code::TEXT;
END;
$$;
