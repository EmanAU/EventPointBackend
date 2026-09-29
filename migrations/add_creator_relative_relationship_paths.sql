-- ============================================================
-- Creator-relative relationship paths for guests and photo feed
-- Examples:
--   Sophia's Colleague
--   Sophia's Colleague's Half Brother
-- ============================================================

DROP FUNCTION IF EXISTS event_get_approved_guests(character varying, character varying);

CREATE FUNCTION event_get_approved_guests("EventId" character varying, "RequestingUserId" character varying)
RETURNS TABLE(
    "GuestUserId" character varying,
    "GuestName" character varying,
    "GuestEmail" character varying,
    "ProfileImageUrl" text,
    "InvitedByUserId" character varying,
    "InviterName" character varying,
    "InviterChain" character varying,
    "RelationshipName" character varying,
    "RelationshipPath" character varying,
    "RelationshipTypeName" character varying,
    "ImagesUploaded" integer,
    "JoinedAt" timestamp with time zone,
    "IsAdmin" boolean,
    "IsCreator" boolean,
    "AdminCode" character varying,
    "ColorId" integer,
    "ColorCode" character varying,
    "InviterColorCode" character varying
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_creator_id VARCHAR;
    v_creator_name VARCHAR;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId"
    ) AND NOT EXISTS (
        SELECT 1 FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId" AND fk_request_status_id = 2
    ) THEN
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to view this list.';
    END IF;

    SELECT e.fk_creator_id, u.name
    INTO v_creator_id, v_creator_name
    FROM events e
    INNER JOIN users u ON u.pk_user_id = e.fk_creator_id
    WHERE e.pk_event_id = "EventId";

    RETURN QUERY
    WITH RECURSIVE relationship_paths AS (
        SELECT
            eg.fk_user_id AS user_id,
            eg.fk_relation_to_user_id AS inviter_user_id,
            ARRAY[eg.fk_user_id]::VARCHAR[] AS visited_user_ids,
            COALESCE(r.relationship_name, '')::VARCHAR AS direct_relationship_name,
            CASE
                WHEN COALESCE(r.relationship_name, '') <> ''
                    THEN (v_creator_name || '''s ' || r.relationship_name)::VARCHAR
                ELSE v_creator_name::VARCHAR
            END AS relationship_path
        FROM event_guests eg
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        WHERE eg.fk_event_id = "EventId"
          AND eg.fk_request_status_id = 2
          AND eg.fk_relation_to_user_id = v_creator_id

        UNION ALL

        SELECT
            eg.fk_user_id AS user_id,
            eg.fk_relation_to_user_id AS inviter_user_id,
            rp.visited_user_ids || eg.fk_user_id,
            COALESCE(r.relationship_name, '')::VARCHAR AS direct_relationship_name,
            CASE
                WHEN COALESCE(r.relationship_name, '') <> ''
                    THEN (rp.relationship_path || '''s ' || r.relationship_name)::VARCHAR
                ELSE rp.relationship_path
            END AS relationship_path
        FROM event_guests eg
        INNER JOIN relationship_paths rp ON rp.user_id = eg.fk_relation_to_user_id
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        WHERE eg.fk_event_id = "EventId"
          AND eg.fk_request_status_id = 2
          AND NOT eg.fk_user_id = ANY(rp.visited_user_ids)
    ),
    creator_rows AS (
        SELECT
            u.pk_user_id AS "GuestUserId",
            u.name AS "GuestName",
            u.email AS "GuestEmail",
            u.profile_image_url AS "ProfileImageUrl",
            NULL::VARCHAR AS "InvitedByUserId",
            NULL::VARCHAR AS "InviterName",
            NULL::VARCHAR AS "InviterChain",
            'Creator'::VARCHAR AS "RelationshipName",
            ''::VARCHAR AS "RelationshipPath",
            ''::VARCHAR AS "RelationshipTypeName",
            0 AS "ImagesUploaded",
            ea.created_at AS "JoinedAt",
            TRUE AS "IsAdmin",
            ea.is_creator AS "IsCreator",
            ea.admin_code AS "AdminCode",
            ea.fk_color_id AS "ColorId",
            c.color_code AS "ColorCode",
            NULL::VARCHAR AS "InviterColorCode"
        FROM event_admins ea
        INNER JOIN users u ON ea.fk_user_id = u.pk_user_id
        LEFT JOIN colors c ON ea.fk_color_id = c.pk_color_id
        WHERE ea.fk_event_id = "EventId" AND ea.is_creator = TRUE
          AND NOT EXISTS (
              SELECT 1 FROM event_guests eg
              WHERE eg.fk_event_id = "EventId" AND eg.fk_user_id = ea.fk_user_id AND eg.fk_request_status_id = 2
          )
    ),
    guest_rows AS (
        SELECT
            u.pk_user_id AS "GuestUserId",
            u.name AS "GuestName",
            u.email AS "GuestEmail",
            u.profile_image_url AS "ProfileImageUrl",
            eg.fk_relation_to_user_id AS "InvitedByUserId",
            inviter.name AS "InviterName",
            COALESCE(
                inviter_path.relationship_path,
                CASE
                    WHEN inviter_admin.is_creator = TRUE THEN inviter.name::VARCHAR
                    ELSE inviter.name::VARCHAR
                END
            ) AS "InviterChain",
            COALESCE(r.relationship_name, CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Member' END) AS "RelationshipName",
            COALESCE(
                guest_path.relationship_path,
                CASE
                    WHEN inviter.name IS NOT NULL AND COALESCE(r.relationship_name, '') <> ''
                        THEN (inviter.name || '''s ' || r.relationship_name)::VARCHAR
                    ELSE COALESCE(r.relationship_name, CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Member' END)
                END
            ) AS "RelationshipPath",
            COALESCE(rt.relationship_type_name, '') AS "RelationshipTypeName",
            eg.images_uploaded_number AS "ImagesUploaded",
            eg.updated_at AS "JoinedAt",
            (ea.pk_event_admin_id IS NOT NULL) AS "IsAdmin",
            COALESCE(ea.is_creator, FALSE) AS "IsCreator",
            ea.admin_code AS "AdminCode",
            ea.fk_color_id AS "ColorId",
            c.color_code AS "ColorCode",
            inviter_color.color_code AS "InviterColorCode"
        FROM event_guests eg
        INNER JOIN users u ON eg.fk_user_id = u.pk_user_id
        LEFT JOIN users inviter ON eg.fk_relation_to_user_id = inviter.pk_user_id
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        LEFT JOIN relationship_types rt ON eg.fk_relationship_type_id = rt.pk_relationship_type_id
        LEFT JOIN event_admins ea ON ea.fk_event_id = "EventId" AND ea.fk_user_id = u.pk_user_id
        LEFT JOIN colors c ON ea.fk_color_id = c.pk_color_id
        LEFT JOIN event_admins inviter_admin ON inviter_admin.fk_event_id = "EventId" AND inviter_admin.fk_user_id = eg.fk_relation_to_user_id
        LEFT JOIN colors inviter_color ON inviter_admin.fk_color_id = inviter_color.pk_color_id
        LEFT JOIN relationship_paths guest_path ON guest_path.user_id = eg.fk_user_id
        LEFT JOIN relationship_paths inviter_path ON inviter_path.user_id = eg.fk_relation_to_user_id
        WHERE eg.fk_event_id = "EventId" AND eg.fk_request_status_id = 2
    )
    SELECT * FROM creator_rows
    UNION ALL
    SELECT * FROM guest_rows
    ORDER BY "IsCreator" DESC, "IsAdmin" DESC, "JoinedAt" DESC;
END;
$$;

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
    "UploaderRelationshipPath" character varying,
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
    v_creator_name VARCHAR;
    v_is_admin BOOLEAN := FALSE;
    v_is_guest BOOLEAN := FALSE;
    v_viewer_chain_types INT[] := ARRAY[]::INT[];
BEGIN
    SELECT e.fk_creator_id, u.name
    INTO v_creator_id, v_creator_name
    FROM events e
    INNER JOIN users u ON u.pk_user_id = e.fk_creator_id
    WHERE e.pk_event_id = "EventId";

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
    WITH RECURSIVE relationship_paths AS (
        SELECT
            eg.fk_user_id AS user_id,
            eg.fk_relation_to_user_id AS inviter_user_id,
            ARRAY[eg.fk_user_id]::VARCHAR[] AS visited_user_ids,
            CASE
                WHEN COALESCE(r.relationship_name, '') <> ''
                    THEN (v_creator_name || '''s ' || r.relationship_name)::VARCHAR
                ELSE v_creator_name::VARCHAR
            END AS relationship_path
        FROM event_guests eg
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        WHERE eg.fk_event_id = "EventId"
          AND eg.fk_request_status_id = 2
          AND eg.fk_relation_to_user_id = v_creator_id

        UNION ALL

        SELECT
            eg.fk_user_id AS user_id,
            eg.fk_relation_to_user_id AS inviter_user_id,
            rp.visited_user_ids || eg.fk_user_id,
            CASE
                WHEN COALESCE(r.relationship_name, '') <> ''
                    THEN (rp.relationship_path || '''s ' || r.relationship_name)::VARCHAR
                ELSE rp.relationship_path
            END AS relationship_path
        FROM event_guests eg
        INNER JOIN relationship_paths rp ON rp.user_id = eg.fk_relation_to_user_id
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        WHERE eg.fk_event_id = "EventId"
          AND eg.fk_request_status_id = 2
          AND NOT eg.fk_user_id = ANY(rp.visited_user_ids)
    ),
    ImagePrivacies AS (
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
        COALESCE(
            (SELECT r.relationship_name FROM event_guests eg3
             LEFT JOIN relationships r ON eg3.fk_relationship_id = r.pk_relationship_id
             WHERE eg3.fk_user_id = u.pk_user_id AND eg3.fk_event_id = "EventId" AND eg3.fk_request_status_id = 2
             LIMIT 1),
            ''
        )::character varying AS "UploaderRelationshipName",
        COALESCE(
            rp.relationship_path,
            CASE
                WHEN img.fk_user_id = v_creator_id THEN ''
                ELSE ''
            END
        )::character varying AS "UploaderRelationshipPath",
        (img.fk_user_id = v_creator_id) AS "IsCreator",
        img.likes_count AS "LikesCount",
        img.created_at AS "CreatedAt",
        COALESCE(img.updated_at, img.created_at) AS "UpdatedAt",
        (EXISTS (SELECT 1 FROM image_likes il WHERE il.fk_image_id = img.pk_event_image_id AND il.fk_user_id = "ViewerUserId")) AS "IsLikedByMe",
        img.is_approved AS "IsApproved",
        COALESCE(
            (SELECT ipv.fk_relationship_type_id FROM image_privacy ipv
             WHERE ipv.fk_event_image_id = img.pk_event_image_id
             LIMIT 1),
            0
        ) AS "ImagePrivacyTypeId"
    FROM event_images img
    INNER JOIN users u ON img.fk_user_id = u.pk_user_id
    LEFT JOIN ImagePrivacies ip ON ip.fk_event_image_id = img.pk_event_image_id
    LEFT JOIN relationship_paths rp ON rp.user_id = img.fk_user_id
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