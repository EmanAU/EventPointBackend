-- ============================================================
-- Add RelationshipTypeId to event_image_create for image privacy
-- When RelationshipTypeId is NULL or 0: Public (everyone in event)
-- When 1,2,3: Insert into image_privacy (Family, Friend, Professional)
-- ============================================================
DROP FUNCTION IF EXISTS event_image_create(character varying, character varying, text, text);
CREATE OR REPLACE FUNCTION event_image_create(
    "EventId" character varying,
    "UserId" character varying,
    "ImageUrl" text,
    "Caption" text DEFAULT '',
    "RelationshipTypeId" integer DEFAULT NULL
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

    -- If RelationshipTypeId is 1, 2, or 3, restrict visibility to that guest category
    IF "RelationshipTypeId" IS NOT NULL AND "RelationshipTypeId" > 0 AND
       "RelationshipTypeId" IN (SELECT pk_relationship_type_id FROM relationship_types) THEN
        INSERT INTO image_privacy (fk_event_image_id, fk_relationship_type_id)
        VALUES (v_new_image_id, "RelationshipTypeId");
    END IF;

    IF v_is_auto_approved THEN
        RETURN QUERY SELECT v_new_image_id, TRUE, 'Image uploaded and auto-approved.'::VARCHAR;
    ELSE
        RETURN QUERY SELECT v_new_image_id, FALSE, 'Image uploaded successfully. Pending admin approval.'::VARCHAR;
    END IF;
END;
$$;
