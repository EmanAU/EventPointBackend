-- Migration: Add 2-photo upload limit for non-admin users in event_image_create
-- Non-admin (regular guest) users can upload a maximum of 2 photos per event.
-- Admins have no upload limit.

CREATE OR REPLACE FUNCTION public.event_image_create(
    "EventId" character varying,
    "UserId" character varying,
    "ImageUrl" text,
    "Caption" text DEFAULT ''::text,
    "RelationshipTypeId" integer DEFAULT 0
)
RETURNS TABLE("ImageId" character varying, "IsApproved" boolean, "Message" character varying)
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_image_id VARCHAR;
    v_is_auto_approved BOOLEAN := FALSE;
    v_guest_id VARCHAR := NULL;
    v_is_admin BOOLEAN := FALSE;
    v_upload_count INT := 0;
BEGIN
    -- 1. Validate Input
    IF "ImageUrl" IS NULL OR length(trim("ImageUrl")) = 0 THEN
        RAISE EXCEPTION 'Image URL cannot be empty';
    END IF;

    -- 2. Security & Context Check
    -- Check if the user is an Admin for this event
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "UserId") THEN
        v_is_auto_approved := TRUE;
        v_is_admin := TRUE;

        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2;

    -- Check if the user is an Approved Guest (Status = 2)
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2) THEN
        v_is_auto_approved := FALSE;

        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

    ELSE
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to upload images.';
    END IF;

    -- 3. Enforce 2-photo limit for non-admin users
    IF NOT v_is_admin THEN
        SELECT COUNT(*) INTO v_upload_count
        FROM event_images
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

        IF v_upload_count >= 2 THEN
            RAISE EXCEPTION 'Upload limit reached: You can upload a maximum of 2 photos per event.';
        END IF;
    END IF;

    -- 4. Insert the Image
    INSERT INTO event_images (
        fk_event_id,
        fk_user_id,
        fk_guest_id,
        image_url,
        caption,
        is_approved,
        created_at,
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
        0
    )
    RETURNING pk_event_image_id INTO v_new_image_id;

    -- 5. Insert privacy rule if RelationshipTypeId > 0
    IF "RelationshipTypeId" > 0 THEN
        INSERT INTO image_privacy (fk_event_image_id, fk_relationship_type_id)
        VALUES (v_new_image_id, "RelationshipTypeId")
        ON CONFLICT (fk_event_image_id, fk_relationship_type_id) DO NOTHING;
    END IF;

    -- 6. Return the result
    IF v_is_auto_approved THEN
        RETURN QUERY SELECT v_new_image_id, TRUE, 'Image uploaded and auto-approved.'::VARCHAR;
    ELSE
        RETURN QUERY SELECT v_new_image_id, FALSE, 'Image uploaded successfully. Pending admin approval.'::VARCHAR;
    END IF;
END;
$$;
