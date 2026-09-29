-- Add venue to public feed for location display
-- Must DROP first because return type changes (adding Venue column)
DROP FUNCTION IF EXISTS public.event_get_public_feed(integer, timestamp with time zone, character varying);
CREATE OR REPLACE FUNCTION public.event_get_public_feed(
    "PageSize" integer DEFAULT 5,
    "CursorDate" timestamp with time zone DEFAULT NULL::timestamp with time zone,
    "CursorEventId" character varying DEFAULT NULL::character varying
)
RETURNS TABLE(
    "EventId" character varying,
    "EventTitle" character varying,
    "CoverImageUrl" text,
    "CategoryName" character varying,
    "SubCategoryName" character varying,
    "Venue" text,
    "CreatedAt" timestamp with time zone
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.pk_event_id AS "EventId",
        e.event_title AS "EventTitle",
        e.event_cover_image_url AS "CoverImageUrl",
        ec.event_category_name AS "CategoryName",
        sc.sub_category_name AS "SubCategoryName",
        COALESCE(e.venue, '')::text AS "Venue",
        e.created_at AS "CreatedAt"
    FROM events e
    LEFT JOIN event_categories ec ON e.fk_event_category_id = ec.pk_event_category_id
    LEFT JOIN sub_categories sc ON e.fk_sub_category_id = sc.pk_sub_category_id
    WHERE e.fk_event_privacy_id = 1
      AND (
          "CursorDate" IS NULL
          OR e.created_at < "CursorDate"
          OR (e.created_at = "CursorDate" AND e.pk_event_id < "CursorEventId")
      )
    ORDER BY e.created_at DESC, e.pk_event_id DESC
    LIMIT "PageSize";
END;
$$;
