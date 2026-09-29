-- ============================================================
-- Migration: Remove prayer edit - allow post and delete only
-- ============================================================

-- 1. prayer_post_or_update: Remove update path - only allow insert
--    If user already has a prayer, return error
CREATE OR REPLACE FUNCTION prayer_post_or_update(
    "EventId" character varying,
    "UserId" character varying,
    "MessageText" text
)
RETURNS TABLE(
    "PrayerId" character varying,
    "IsSuccess" boolean,
    "Message" character varying
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_id VARCHAR;
    v_guest_id VARCHAR := NULL;
    v_is_authorized BOOLEAN := FALSE;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    -- 1. Check admin
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "UserId") THEN
        v_is_authorized := TRUE;
        v_is_admin := TRUE;
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2) THEN
        v_is_authorized := TRUE;
        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";
    END IF;

    IF NOT v_is_authorized THEN
        RETURN QUERY SELECT NULL::VARCHAR, FALSE, 'Unauthorized: You must be an admin or approved guest to post.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Check existing - no edit allowed, user must delete first
    SELECT pk_event_prayer_id INTO v_existing_id
    FROM event_prayers
    WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

    IF v_existing_id IS NOT NULL THEN
        RETURN QUERY SELECT v_existing_id, FALSE, 'You already have a prayer. Delete it first to post a new one.'::VARCHAR;
        RETURN;
    END IF;

    -- 3. Insert new prayer only
    INSERT INTO event_prayers (
        fk_event_id,
        fk_user_id,
        fk_guest_id,
        prayer_message,
        is_approved,
        created_at
    )
    VALUES (
        "EventId",
        "UserId",
        v_guest_id,
        TRIM("MessageText"),
        v_is_admin,
        NOW()
    )
    RETURNING pk_event_prayer_id INTO v_existing_id;

    RETURN QUERY SELECT v_existing_id, TRUE, 'Prayer posted successfully.'::VARCHAR;
END;
$$;

-- 2. prayers_get: Always return CanEdit = false (edit removed)
DROP FUNCTION IF EXISTS prayers_get(character varying, character varying);
CREATE OR REPLACE FUNCTION prayers_get(
    "EventId" character varying,
    "ViewerUserId" character varying
)
RETURNS TABLE(
    "PrayerId" character varying,
    "UserId" character varying,
    "UserName" character varying,
    "ProfileImageUrl" text,
    "PrayerMessage" text,
    "CreatedAt" timestamp with time zone,
    "IsMyMessage" boolean,
    "CanEdit" boolean,
    "IsApproved" boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_privacy_id INT;
    v_is_authorized BOOLEAN := FALSE;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    SELECT fk_event_privacy_id INTO v_event_privacy_id
    FROM events WHERE pk_event_id = "EventId";

    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId") THEN
        v_is_authorized := TRUE;
        v_is_admin := TRUE;
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId" AND fk_request_status_id = 2) THEN
        v_is_authorized := TRUE;
    END IF;

    IF v_event_privacy_id = 2 AND NOT v_is_authorized THEN
        RAISE EXCEPTION 'This event is private. Only approved guests can view the prayer wall.';
    END IF;

    RETURN QUERY
    SELECT
        ep.pk_event_prayer_id AS "PrayerId",
        u.pk_user_id AS "UserId",
        u.name AS "UserName",
        u.profile_image_url AS "ProfileImageUrl",
        ep.prayer_message AS "PrayerMessage",
        ep.created_at AS "CreatedAt",
        (u.pk_user_id = "ViewerUserId") AS "IsMyMessage",
        FALSE AS "CanEdit",  -- Edit removed - delete only
        COALESCE(ep.is_approved, FALSE) AS "IsApproved"
    FROM event_prayers ep
    INNER JOIN users u ON ep.fk_user_id = u.pk_user_id
    WHERE ep.fk_event_id = "EventId"
      AND (
          v_is_admin
          OR ep.is_approved = TRUE
          OR ep.fk_user_id = "ViewerUserId"
      )
    ORDER BY ep.created_at DESC;
END;
$$;
