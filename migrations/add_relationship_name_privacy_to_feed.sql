-- ============================================================
-- image_get_feed_private: Add UploaderRelationshipName + ImagePrivacyTypeId
-- ============================================================
-- UploaderRelationshipName = specific relation (e.g. Colleague, Brother)
-- ImagePrivacyTypeId       = 0 if no image_privacy row, else the relationship_type_id
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
    "UploaderRelationshipName" character varying,
    "IsCreator" boolean,
    "LikesCount" integer,
    "CreatedAt" timestamp with time zone,
    "UpdatedAt" timestamp with time zone,
    "IsLikedByMe" boolean,
    "IsApproved" boolean,
    "ImagePrivacyTypeId" integer
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
        -- UploaderRelation: relationship TYPE name (Family/Friend/Professional/Creator/Guest)
        COALESCE(
            (SELECT rt.relationship_type_name FROM event_guests eg2
             LEFT JOIN relationship_types rt ON eg2.fk_relationship_type_id = rt.pk_relationship_type_id
             WHERE eg2.fk_user_id = u.pk_user_id AND eg2.fk_event_id = "EventId" AND eg2.fk_request_status_id = 2
             LIMIT 1),
            CASE WHEN img.fk_user_id = v_creator_id THEN 'Creator' ELSE 'Guest' END
        ) AS "UploaderRelation",
        -- UploaderRelationshipName: specific relationship (Colleague/Brother/Best Friend etc.)
        COALESCE(
            (SELECT r.relationship_name FROM event_guests eg3
             LEFT JOIN relationships r ON eg3.fk_relationship_id = r.pk_relationship_id
             WHERE eg3.fk_user_id = u.pk_user_id AND eg3.fk_event_id = "EventId" AND eg3.fk_request_status_id = 2
             LIMIT 1),
            ''
        )::character varying AS "UploaderRelationshipName",
        (img.fk_user_id = v_creator_id) AS "IsCreator",
        img.likes_count AS "LikesCount",
        img.created_at AS "CreatedAt",
        COALESCE(img.updated_at, img.created_at) AS "UpdatedAt",
        (EXISTS (SELECT 1 FROM image_likes il WHERE il.fk_image_id = img.pk_event_image_id AND il.fk_user_id = "ViewerUserId")) AS "IsLikedByMe",
        img.is_approved AS "IsApproved",
        -- ImagePrivacyTypeId: 0 = Everyone (no privacy row), else the first privacy type
        COALESCE(
            (SELECT ipv.fk_relationship_type_id FROM image_privacy ipv
             WHERE ipv.fk_event_image_id = img.pk_event_image_id
             LIMIT 1),
            0
        ) AS "ImagePrivacyTypeId"
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
