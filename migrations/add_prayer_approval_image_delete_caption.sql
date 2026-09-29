-- ============================================================
-- Migration: Prayer Wall approval, image delete, captions,
--            prayer participants, max-2-images-per-user limit
-- ============================================================

-- 1. Add is_approved column to event_prayers (default FALSE, admin/creator auto-approved)
ALTER TABLE event_prayers ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT FALSE;
-- Backfill existing prayers as approved
UPDATE event_prayers SET is_approved = TRUE WHERE is_approved IS NULL OR is_approved = FALSE;

-- 2. Add caption column to event_images
ALTER TABLE event_images ADD COLUMN IF NOT EXISTS caption TEXT DEFAULT '';
ALTER TABLE event_images ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- ============================================================
-- prayer_post_or_update: Updated to set is_approved for admin/creator
-- ============================================================
-- Return shape must not change with CREATE OR REPLACE; if a later
-- migration (e.g. add_prayer_post_pending_approval_return.sql) already
-- added columns, or the DB is re-run, drop first.
DROP FUNCTION IF EXISTS prayer_post_or_update(character varying, character varying, text);
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
    v_created_at TIMESTAMPTZ;
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

    -- 2. Check existing
    SELECT pk_event_prayer_id, created_at
    INTO v_existing_id, v_created_at
    FROM event_prayers
    WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

    -- 3. Update
    IF v_existing_id IS NOT NULL THEN
        IF NOW() > v_created_at + INTERVAL '1 hour' THEN
            RETURN QUERY SELECT v_existing_id, FALSE, 'Time limit exceeded. You can only edit your message within 1 hour of posting.'::VARCHAR;
            RETURN;
        END IF;

        UPDATE event_prayers
        SET prayer_message = TRIM("MessageText"),
            is_approved = CASE WHEN v_is_admin THEN TRUE ELSE is_approved END
        WHERE pk_event_prayer_id = v_existing_id;

        RETURN QUERY SELECT v_existing_id, TRUE, 'Prayer updated successfully.'::VARCHAR;

    -- 4. Insert
    ELSE
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
            v_is_admin,  -- admin/creator auto-approved
            NOW()
        )
        RETURNING pk_event_prayer_id INTO v_existing_id;

        RETURN QUERY SELECT v_existing_id, TRUE, 'Prayer posted successfully.'::VARCHAR;
    END IF;
END;
$$;

-- ============================================================
-- prayer_approve: Admin/creator approves a prayer
-- ============================================================
DROP FUNCTION IF EXISTS prayer_approve(character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION prayer_approve(
    "EventId" character varying,
    "PrayerId" character varying,
    "AdminUserId" character varying
)
RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Must be admin
    IF NOT EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId" AND fk_user_id = "AdminUserId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: Only admins can approve prayers.'::VARCHAR;
        RETURN;
    END IF;

    -- Find prayer
    IF NOT EXISTS (
        SELECT 1 FROM event_prayers
        WHERE pk_event_prayer_id = "PrayerId" AND fk_event_id = "EventId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'Prayer not found.'::VARCHAR;
        RETURN;
    END IF;

    UPDATE event_prayers SET is_approved = TRUE
    WHERE pk_event_prayer_id = "PrayerId";

    RETURN QUERY SELECT TRUE, 'Prayer approved successfully.'::VARCHAR;
END;
$$;

-- ============================================================
-- prayers_get: Updated to include IsApproved, only show approved to non-admins
-- ============================================================
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
        (u.pk_user_id = "ViewerUserId" AND NOW() <= ep.created_at + INTERVAL '1 hour') AS "CanEdit",
        COALESCE(ep.is_approved, FALSE) AS "IsApproved"
    FROM event_prayers ep
    INNER JOIN users u ON ep.fk_user_id = u.pk_user_id
    WHERE ep.fk_event_id = "EventId"
      AND (
          v_is_admin                         -- admins see all
          OR ep.is_approved = TRUE           -- non-admins see approved
          OR ep.fk_user_id = "ViewerUserId"  -- or their own
      )
    ORDER BY ep.created_at DESC;
END;
$$;

-- ============================================================
-- prayer_get_participants: For avatar stack + count
-- ============================================================
DROP FUNCTION IF EXISTS prayer_get_participants(character varying);
CREATE OR REPLACE FUNCTION prayer_get_participants(
    "EventId" character varying
)
RETURNS TABLE(
    "UserId" character varying,
    "UserName" character varying,
    "ProfileImageUrl" text,
    "TotalCount" bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH approved_prayers AS (
        SELECT DISTINCT ep.fk_user_id
        FROM event_prayers ep
        WHERE ep.fk_event_id = "EventId"
          AND ep.is_approved = TRUE
    ),
    total AS (
        SELECT COUNT(*) AS cnt FROM approved_prayers
    )
    SELECT
        u.pk_user_id AS "UserId",
        u.name AS "UserName",
        u.profile_image_url AS "ProfileImageUrl",
        t.cnt AS "TotalCount"
    FROM approved_prayers ap
    INNER JOIN users u ON ap.fk_user_id = u.pk_user_id
    CROSS JOIN total t
    ORDER BY u.name
    LIMIT 10;
END;
$$;

-- ============================================================
-- event_image_create: Updated with caption + max 2 per user check
-- ============================================================
DROP FUNCTION IF EXISTS event_image_create(character varying, character varying, text, text);
DROP FUNCTION IF EXISTS event_image_create(character varying, character varying, text);
CREATE OR REPLACE FUNCTION event_image_create(
    "EventId" character varying,
    "UserId" character varying,
    "ImageUrl" text,
    "Caption" text DEFAULT ''
)
RETURNS TABLE(
    "ImageId" character varying,
    "IsApproved" boolean,
    "Message" character varying
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_image_id VARCHAR;
    v_is_auto_approved BOOLEAN := FALSE;
    v_guest_id VARCHAR := NULL;
    v_image_count INT := 0;
BEGIN
    IF "ImageUrl" IS NULL OR length(trim("ImageUrl")) = 0 THEN
        RAISE EXCEPTION 'Image URL cannot be empty';
    END IF;

    -- Check admin
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "UserId") THEN
        v_is_auto_approved := TRUE;
        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2;

    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2) THEN
        v_is_auto_approved := FALSE;
        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";
    ELSE
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to upload images.';
    END IF;

    -- Max 2 images per regular user (admins unlimited)
    IF NOT v_is_auto_approved THEN
        SELECT COUNT(*) INTO v_image_count
        FROM event_images
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

        IF v_image_count >= 2 THEN
            RETURN QUERY SELECT NULL::VARCHAR, FALSE, 'You can upload a maximum of 2 photos per event.'::VARCHAR;
            RETURN;
        END IF;
    END IF;

    INSERT INTO event_images (
        fk_event_id,
        fk_user_id,
        fk_guest_id,
        image_url,
        caption,
        is_approved,
        created_at,
        updated_at,
        likes_count
    )
    VALUES (
        "EventId",
        "UserId",
        v_guest_id,
        TRIM("ImageUrl"),
        COALESCE(TRIM("Caption"), ''),
        v_is_auto_approved,
        NOW(),
        NOW(),
        0
    )
    RETURNING pk_event_image_id INTO v_new_image_id;

    IF v_is_auto_approved THEN
        RETURN QUERY SELECT v_new_image_id, TRUE, 'Image uploaded and auto-approved.'::VARCHAR;
    ELSE
        RETURN QUERY SELECT v_new_image_id, FALSE, 'Image uploaded successfully. Pending admin approval.'::VARCHAR;
    END IF;
END;
$$;

-- ============================================================
-- event_image_delete: Delete image (owner or admin)
-- ============================================================
DROP FUNCTION IF EXISTS event_image_delete(character varying, character varying, character varying);
CREATE OR REPLACE FUNCTION event_image_delete(
    "EventId" character varying,
    "ImageId" character varying,
    "RequestingUserId" character varying
)
RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id VARCHAR;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    SELECT fk_user_id INTO v_owner_id
    FROM event_images
    WHERE pk_event_image_id = "ImageId" AND fk_event_id = "EventId";

    IF v_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Image not found.'::VARCHAR;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId") THEN
        v_is_admin := TRUE;
    END IF;

    IF v_is_admin THEN
        DELETE FROM event_images WHERE pk_event_image_id = "ImageId";
        RETURN QUERY SELECT TRUE, 'Image deleted by Admin.'::VARCHAR;
    ELSIF v_owner_id = "RequestingUserId" THEN
        DELETE FROM event_images WHERE pk_event_image_id = "ImageId";
        RETURN QUERY SELECT TRUE, 'Your image was deleted.'::VARCHAR;
    ELSE
        RETURN QUERY SELECT FALSE, 'Unauthorized to delete this image.'::VARCHAR;
    END IF;
END;
$$;

-- ============================================================
-- image_get_feed_private: Updated to include Caption
-- ============================================================
DROP FUNCTION IF EXISTS image_get_feed_private(character varying, character varying, integer, timestamp with time zone, character varying);
CREATE OR REPLACE FUNCTION image_get_feed_private(
    "EventId" character varying,
    "ViewerUserId" character varying,
    "PageSize" integer DEFAULT 20,
    "CursorDate" timestamp with time zone DEFAULT NULL,
    "CursorImageId" character varying DEFAULT NULL
)
RETURNS TABLE(
    "ImageId" character varying,
    "ImageUrl" text,
    "Caption" text,
    "UploaderId" character varying,
    "UploaderName" character varying,
    "UploaderProfileImageUrl" text,
    "UploaderRelation" character varying,
    "IsCreator" boolean,
    "LikesCount" integer,
    "CreatedAt" timestamp with time zone,
    "UpdatedAt" timestamp with time zone,
    "IsLikedByMe" boolean,
    "IsApproved" boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_creator_id VARCHAR;
    v_is_admin BOOLEAN := FALSE;
    v_is_guest BOOLEAN := FALSE;
    v_viewer_chain_types INT[] := ARRAY[]::INT[];
BEGIN
    SELECT fk_creator_id INTO v_creator_id FROM events WHERE pk_event_id = "EventId";

    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId") THEN
        v_is_admin := TRUE;
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId" AND fk_request_status_id = 2) THEN
        v_is_guest := TRUE;

        WITH RECURSIVE Ancestors AS (
            SELECT fk_user_id, fk_relation_to_user_id, fk_relationship_type_id
            FROM event_guests
            WHERE fk_user_id = "ViewerUserId" AND fk_event_id = "EventId"
            UNION ALL
            SELECT eg.fk_user_id, eg.fk_relation_to_user_id, eg.fk_relationship_type_id
            FROM event_guests eg
            INNER JOIN Ancestors a ON a.fk_relation_to_user_id = eg.fk_user_id
            WHERE eg.fk_event_id = "EventId"
        )
        SELECT array_agg(DISTINCT fk_relationship_type_id)
        INTO v_viewer_chain_types
        FROM Ancestors
        WHERE fk_relationship_type_id IS NOT NULL;

        IF v_viewer_chain_types IS NULL THEN v_viewer_chain_types := ARRAY[]::INT[]; END IF;
    END IF;

    IF NOT v_is_admin AND NOT v_is_guest THEN
        RAISE EXCEPTION 'Unauthorized: You are not a guest of this event.';
    END IF;

    RETURN QUERY
    WITH ImagePrivacies AS (
        SELECT fk_event_image_id, array_agg(fk_relationship_type_id) as allowed_types
        FROM image_privacy
        GROUP BY fk_event_image_id
    )
    SELECT
        img.pk_event_image_id AS "ImageId",
        img.image_url AS "ImageUrl",
        COALESCE(img.caption, '') AS "Caption",
        u.pk_user_id AS "UploaderId",
        u.name AS "UploaderName",
        u.profile_image_url AS "UploaderProfileImageUrl",
        COALESCE(
            (SELECT rt.relationship_type_name FROM event_guests eg2
             LEFT JOIN relationship_types rt ON eg2.fk_relationship_type_id = rt.pk_relationship_type_id
             WHERE eg2.fk_user_id = u.pk_user_id AND eg2.fk_event_id = "EventId" AND eg2.fk_request_status_id = 2
             LIMIT 1),
            CASE WHEN img.fk_user_id = v_creator_id THEN 'Creator' ELSE 'Guest' END
        ) AS "UploaderRelation",
        (img.fk_user_id = v_creator_id) AS "IsCreator",
        img.likes_count AS "LikesCount",
        img.created_at AS "CreatedAt",
        COALESCE(img.updated_at, img.created_at) AS "UpdatedAt",
        (EXISTS (SELECT 1 FROM image_likes il WHERE il.fk_image_id = img.pk_event_image_id AND il.fk_user_id = "ViewerUserId")) AS "IsLikedByMe",
        img.is_approved AS "IsApproved"
    FROM event_images img
    INNER JOIN users u ON img.fk_user_id = u.pk_user_id
    LEFT JOIN ImagePrivacies ip ON ip.fk_event_image_id = img.pk_event_image_id
    WHERE img.fk_event_id = "EventId"
      AND (
          v_is_admin
          OR (img.is_approved = TRUE AND (
              img.fk_user_id = "ViewerUserId"
              OR ip.allowed_types IS NULL
              OR (v_is_guest AND v_viewer_chain_types && ip.allowed_types)
          ))
          OR img.fk_user_id = "ViewerUserId"
      )
      AND ("CursorDate" IS NULL OR img.created_at < "CursorDate" OR (img.created_at = "CursorDate" AND img.pk_event_image_id < "CursorImageId"))
    ORDER BY img.created_at DESC, img.pk_event_image_id DESC
    LIMIT "PageSize";
END;
$$;
