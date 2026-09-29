--
-- PostgreSQL database dump - EventPoint full restore
-- Modified: Drops existing schema and fixes known issues
--
-- Drop existing schema to avoid conflicts
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO "default";
GRANT ALL ON SCHEMA public TO public;

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-02-22 15:11:40

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 268 (class 1255 OID 40962)
-- Name: categories_get(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.categories_get() RETURNS TABLE("EventCategoryId" integer, "EventCategoryName" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_event_category_id, 
        event_category_name 
    FROM 
        event_categories;
END;
$$;


ALTER FUNCTION public.categories_get() OWNER TO "default";

--
-- TOC entry 280 (class 1255 OID 41008)
-- Name: event_create(integer, integer, character varying, character varying, timestamp with time zone, text, text, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_create("CategoryId" integer, "PrivacyId" integer, "Title" character varying, "CreatorUserId" character varying, "EventDateTime" timestamp with time zone, "Venue" text, "CoverImageUrl" text, "TagLine" character varying DEFAULT NULL::character varying, "ExpectedGuests" integer DEFAULT 0, "SubCategoryId" integer DEFAULT NULL::integer) RETURNS TABLE("EventId" character varying, "AdminCode" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_event_id VARCHAR;
    v_admin_code VARCHAR;
BEGIN
    -- 1. Insert Event (Now including the Privacy ID)
    INSERT INTO events (
        fk_event_category_id, 
        fk_sub_category_id, 
        fk_event_privacy_id, 
        event_title, 
        tag_line, 
        expected_guest_number, 
        venue, 
        event_date_time, 
        event_cover_image_url, 
        fk_creator_id, 
        created_at
    )
    VALUES (
        "CategoryId", 
        "SubCategoryId", 
        "PrivacyId",
        TRIM("Title"), 
        TRIM("TagLine"), 
        "ExpectedGuests", 
        TRIM("Venue"), 
        "EventDateTime", 
        TRIM("CoverImageUrl"), 
        "CreatorUserId", 
        NOW()
    )
    RETURNING pk_event_id INTO v_new_event_id;

    -- 2. Add Creator as Admin
    v_admin_code := generate_random_id(6);
    
    INSERT INTO event_admins (
        fk_user_id, fk_event_id, admin_code, is_creator, fk_color_id, created_at
    )
    VALUES (
        "CreatorUserId", v_new_event_id, v_admin_code, TRUE, 1, NOW()
    );

    RETURN QUERY SELECT v_new_event_id, v_admin_code;
END;
$$;


ALTER FUNCTION public.event_create("CategoryId" integer, "PrivacyId" integer, "Title" character varying, "CreatorUserId" character varying, "EventDateTime" timestamp with time zone, "Venue" text, "CoverImageUrl" text, "TagLine" character varying, "ExpectedGuests" integer, "SubCategoryId" integer) OWNER TO "default";

--
-- TOC entry 277 (class 1255 OID 40985)
-- Name: event_get_approved_guests(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_get_approved_guests("EventId" character varying, "RequestingUserId" character varying) RETURNS TABLE("GuestUserId" character varying, "GuestName" character varying, "GuestEmail" character varying, "ProfileImageUrl" text, "InvitedByUserId" character varying, "InviterName" character varying, "RelationshipName" character varying, "RelationshipTypeName" character varying, "ImagesUploaded" integer, "JoinedAt" timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- They must be either an Admin (which includes the Creator) OR an Approved Guest (Status = 2)
    IF NOT EXISTS (
        SELECT 1 FROM event_admins 
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId"
    ) AND NOT EXISTS (
        SELECT 1 FROM event_guests 
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId" AND fk_request_status_id = 2
    ) THEN
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to view this list.';
    END IF;

    -- 2. FETCH THE DATA
    RETURN QUERY
    SELECT 
        u.pk_user_id AS "GuestUserId",
        u.name AS "GuestName",
        u.email AS "GuestEmail",
        u.profile_image_url AS "ProfileImageUrl",
        
        eg.fk_relation_to_user_id AS "InvitedByUserId", 
        
        -- We join the users table a SECOND time just to get the Inviter's Name
        inviter.name AS "InviterName", 
        
        r.relationship_name AS "RelationshipName",
        rt.relationship_type_name AS "RelationshipTypeName",
        eg.images_uploaded_number AS "ImagesUploaded",
        eg.updated_at AS "JoinedAt"
        
    FROM event_guests eg
    INNER JOIN users u ON eg.fk_user_id = u.pk_user_id
    
    -- LEFT JOIN to get the name of the person who invited them
    LEFT JOIN users inviter ON eg.fk_relation_to_user_id = inviter.pk_user_id 
    
    LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
    LEFT JOIN relationship_types rt ON eg.fk_relationship_type_id = rt.pk_relationship_type_id
    
    WHERE eg.fk_event_id = "EventId"
      AND eg.fk_request_status_id = 2 -- 2 = Accepted
      
    ORDER BY eg.updated_at DESC;
END;
$$;


ALTER FUNCTION public.event_get_approved_guests("EventId" character varying, "RequestingUserId" character varying) OWNER TO "default";

--
-- TOC entry 272 (class 1255 OID 40972)
-- Name: event_get_pending_requests(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_get_pending_requests("AdminUserId" character varying, "EventId" character varying) RETURNS TABLE("GuestUserId" character varying, "GuestName" character varying, "RequestTime" timestamp with time zone, "Status" character varying, "GuestEmail" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.fk_user_id AS "GuestUserId",
        u.name AS "GuestName",
        g.created_at AS "RequestTime",
        rs.status_name AS "Status",
        u.email AS "GuestEmail"
    FROM event_guests g
    INNER JOIN users u ON g.fk_user_id = u.pk_user_id
    INNER JOIN request_statuses rs ON g.fk_request_status_id = rs.pk_request_status_id
    WHERE g.fk_event_id = "EventId"
      -- CRITICAL RULE: Only show guests who used THIS Admin's code
      -- We stored the Admin's ID in this column during the join_request function
      AND g.fk_relation_to_user_id = "AdminUserId" 
      AND g.fk_request_status_id = 1; -- 1 = Pending
END;
$$;


ALTER FUNCTION public.event_get_pending_requests("AdminUserId" character varying, "EventId" character varying) OWNER TO "default";

--
-- TOC entry 286 (class 1255 OID 41027)
-- Name: event_get_public_feed(integer, timestamp with time zone, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_get_public_feed("PageSize" integer DEFAULT 5, "CursorDate" timestamp with time zone DEFAULT NULL::timestamp with time zone, "CursorEventId" character varying DEFAULT NULL::character varying) RETURNS TABLE("EventId" character varying, "EventTitle" character varying, "CoverImageUrl" text, "CategoryName" character varying, "SubCategoryName" character varying, "CreatedAt" timestamp with time zone)
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
        e.created_at AS "CreatedAt"
    FROM events e
    LEFT JOIN event_categories ec ON e.fk_event_category_id = ec.pk_event_category_id
    LEFT JOIN sub_categories sc ON e.fk_sub_category_id = sc.pk_sub_category_id
    WHERE e.fk_event_privacy_id = 1 -- 1 = Public Events
      -- Cursor Pagination: 
      -- If CursorDate is NULL, it gets the absolute newest events.
      -- Otherwise, it gets events older than the cursor.
      AND (
          "CursorDate" IS NULL 
          OR e.created_at < "CursorDate" 
          OR (e.created_at = "CursorDate" AND e.pk_event_id < "CursorEventId")
      )
    ORDER BY e.created_at DESC, e.pk_event_id DESC
    LIMIT "PageSize";
END;
$$;


ALTER FUNCTION public.event_get_public_feed("PageSize" integer, "CursorDate" timestamp with time zone, "CursorEventId" character varying) OWNER TO "default";

--
-- TOC entry 271 (class 1255 OID 40971)
-- Name: event_guest_approve(character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_guest_approve("AdminUserId" character varying, "TargetGuestId" character varying, "EventId" character varying, "RelationshipTypeId" integer, "RelationshipId" integer) RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Security: Only Admins can approve
    IF NOT EXISTS (SELECT 1 FROM event_admins WHERE fk_user_id = "AdminUserId" AND fk_event_id = "EventId") THEN
        -- FIX: Added ::varchar
        RETURN QUERY SELECT FALSE, 'Unauthorized: You are not an admin.'::varchar;
        RETURN;
    END IF;

    -- 2. Update Guest Status to Accepted (2)
    UPDATE event_guests
    SET 
        fk_request_status_id = 2,
        fk_relationship_type_id = "RelationshipTypeId",
        fk_relationship_id = "RelationshipId",
        updated_at = NOW()
    WHERE fk_user_id = "TargetGuestId" AND fk_event_id = "EventId";

    IF FOUND THEN
        -- FIX: Added ::varchar
        RETURN QUERY SELECT TRUE, 'Guest Approved Successfully'::varchar;
    ELSE
        -- FIX: Added ::varchar
        RETURN QUERY SELECT FALSE, 'Guest request not found.'::varchar;
    END IF;
END;
$$;


ALTER FUNCTION public.event_guest_approve("AdminUserId" character varying, "TargetGuestId" character varying, "EventId" character varying, "RelationshipTypeId" integer, "RelationshipId" integer) OWNER TO "default";

--
-- TOC entry 285 (class 1255 OID 41026)
-- Name: event_guest_remove(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_guest_remove("AdminUserId" character varying, "TargetUserId" character varying, "EventId" character varying) RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_caller_is_creator BOOLEAN;
    v_target_is_admin BOOLEAN := FALSE;
    v_target_is_creator BOOLEAN := FALSE;
BEGIN
    -- 1. Check who is making the request (Caller)
    SELECT is_creator INTO v_caller_is_creator
    FROM event_admins 
    WHERE fk_user_id = "AdminUserId" AND fk_event_id = "EventId";

    IF v_caller_is_creator IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: You are not an admin of this group.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Check who is being removed (Target)
    SELECT is_creator INTO v_target_is_creator
    FROM event_admins
    WHERE fk_user_id = "TargetUserId" AND fk_event_id = "EventId";

    IF FOUND THEN
        v_target_is_admin := TRUE;
    END IF;

    -- 3. Apply the strict removal rules
    IF v_target_is_admin THEN
        
        -- Rule A: Nobody can remove the Creator
        IF v_target_is_creator THEN
            RETURN QUERY SELECT FALSE, 'The creator of the group cannot be removed.'::VARCHAR;
            RETURN;
        END IF;

        -- Rule B: Only the Creator can remove another Admin
        IF NOT v_caller_is_creator THEN
            RETURN QUERY SELECT FALSE, 'Unauthorized: Only the group creator can remove an admin.'::VARCHAR;
            RETURN;
        END IF;

        -- If checks pass, remove them from the admins table first
        DELETE FROM event_admins 
        WHERE fk_user_id = "TargetUserId" AND fk_event_id = "EventId";
    END IF;

    -- 4. Remove from the guests table
    -- (This runs for regular guests, AND for admins who were just removed above)
    DELETE FROM event_guests 
    WHERE fk_user_id = "TargetUserId" AND fk_event_id = "EventId";

    RETURN QUERY SELECT TRUE, 'User successfully removed from the group.'::VARCHAR;
END;
$$;


ALTER FUNCTION public.event_guest_remove("AdminUserId" character varying, "TargetUserId" character varying, "EventId" character varying) OWNER TO "default";

--
-- TOC entry 276 (class 1255 OID 40983)
-- Name: event_guest_request_accept(character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_guest_request_accept("AdminUserId" character varying, "TargetGuestUserId" character varying, "EventId" character varying, "RelationshipTypeId" integer, "RelationshipId" integer) RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Security Check: Is the caller actually an Admin of this event?
    IF NOT EXISTS (
        SELECT 1 FROM event_admins 
        WHERE fk_user_id = "AdminUserId" AND fk_event_id = "EventId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: You are not an admin of this event.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Strict Validation: 
    -- Ensure the request exists AND was invited by THIS Admin (Chain of Trust)
    IF NOT EXISTS (
        SELECT 1 FROM event_guests 
        WHERE fk_user_id = "TargetGuestUserId" 
          AND fk_event_id = "EventId"
          AND fk_relation_to_user_id = "AdminUserId" -- Strict Rule: Must match the inviter
          AND fk_request_status_id = 1 -- Must be Pending
    ) THEN
        RETURN QUERY SELECT FALSE, 'Request not found, or you do not have permission to approve this specific guest (they may have used another admin''s code).'::VARCHAR;
        RETURN;
    END IF;

    -- 3. Update the Guest Record (Approve them)
    UPDATE event_guests
    SET 
        fk_request_status_id = 2, -- 2 = Accepted
        fk_relationship_type_id = "RelationshipTypeId",
        fk_relationship_id = "RelationshipId",
        updated_at = NOW()
    WHERE fk_user_id = "TargetGuestUserId" 
      AND fk_event_id = "EventId"
      AND fk_relation_to_user_id = "AdminUserId"; -- Double check for safety

    -- 4. Return Success
    RETURN QUERY SELECT TRUE, 'Guest request accepted successfully.'::VARCHAR;
END;
$$;


ALTER FUNCTION public.event_guest_request_accept("AdminUserId" character varying, "TargetGuestUserId" character varying, "EventId" character varying, "RelationshipTypeId" integer, "RelationshipId" integer) OWNER TO "default";

--
-- TOC entry 273 (class 1255 OID 40987)
-- Name: event_image_approve(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_image_approve("AdminUserId" character varying, "ImageId" character varying) RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_id VARCHAR;
BEGIN
    -- 1. Find the Event ID associated with this image
    SELECT fk_event_id INTO v_event_id
    FROM event_images
    WHERE pk_event_image_id = "ImageId";

    IF v_event_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Image not found.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Security Check: Is the caller an Admin for this specific event?
    IF NOT EXISTS (
        SELECT 1 FROM event_admins 
        WHERE fk_event_id = v_event_id AND fk_user_id = "AdminUserId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: Only admins can approve images.'::VARCHAR;
        RETURN;
    END IF;

    -- 3. Approve the Image
    UPDATE event_images
    SET is_approved = TRUE
    WHERE pk_event_image_id = "ImageId";

    -- 4. Return Success
    RETURN QUERY SELECT TRUE, 'Image approved successfully.'::VARCHAR;
END;
$$;


ALTER FUNCTION public.event_image_approve("AdminUserId" character varying, "ImageId" character varying) OWNER TO "default";

--
-- TOC entry 278 (class 1255 OID 40986)
-- Name: event_image_create(character varying, character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_image_create("EventId" character varying, "UserId" character varying, "ImageUrl" text) RETURNS TABLE("ImageId" character varying, "IsApproved" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_image_id VARCHAR;
    v_is_auto_approved BOOLEAN := FALSE;
    v_guest_id VARCHAR := NULL;
BEGIN
    -- 1. Validate Input
    IF "ImageUrl" IS NULL OR length(trim("ImageUrl")) = 0 THEN
        RAISE EXCEPTION 'Image URL cannot be empty';
    END IF;

    -- 2. Security & Context Check
    -- Check if the user is an Admin for this event
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "UserId") THEN
        v_is_auto_approved := TRUE; -- Admins don't need approval
        
        -- Try to get their Guest ID (just in case an Admin was also invited as a guest)
        SELECT pk_event_guest_id INTO v_guest_id 
        FROM event_guests 
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2;

    -- Check if the user is an Approved Guest (Status = 2)
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2) THEN
        v_is_auto_approved := FALSE; -- Regular guests need admin approval
        
        -- Fetch their Guest ID
        SELECT pk_event_guest_id INTO v_guest_id 
        FROM event_guests 
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";
        
    ELSE
        -- If they are neither an Admin nor an Approved Guest, block the upload
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to upload images.';
    END IF;

    -- 3. Insert the Image
    INSERT INTO event_images (
        fk_event_id,
        fk_user_id,
        fk_guest_id,
        image_url,
        is_approved,
        created_at,
        likes_count
    )
    VALUES (
        "EventId",
        "UserId",
        v_guest_id,
        TRIM("ImageUrl"),
        v_is_auto_approved,
        NOW(),
        0
    )
    RETURNING pk_event_image_id INTO v_new_image_id;

    -- 4. Return the result to C#
    IF v_is_auto_approved THEN
        RETURN QUERY SELECT v_new_image_id, TRUE, 'Image uploaded and auto-approved.'::VARCHAR;
    ELSE
        RETURN QUERY SELECT v_new_image_id, FALSE, 'Image uploaded successfully. Pending admin approval.'::VARCHAR;
    END IF;

END;
$$;


ALTER FUNCTION public.event_image_create("EventId" character varying, "UserId" character varying, "ImageUrl" text) OWNER TO "default";

--
-- TOC entry 267 (class 1255 OID 32770)
-- Name: event_image_create(character varying, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_image_create(p_fk_event_id character varying, p_image_url text, p_fk_user_id integer DEFAULT NULL::integer, p_fk_guest_id integer DEFAULT NULL::integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_image_id INT;
BEGIN
    -- Validate URL
    IF p_image_url IS NULL OR length(trim(p_image_url)) = 0 THEN
        RAISE EXCEPTION 'Image URL cannot be empty';
    END IF;

    INSERT INTO event_images (
        fk_event_id,
        fk_user_id,
        fk_guest_id,
        image_url,
        created_at
    )
    VALUES (
        p_fk_event_id,
        p_fk_user_id,
        p_fk_guest_id,
        TRIM(p_image_url),
        NOW()
    )
    RETURNING pk_event_image_id INTO v_new_image_id; 

    RETURN v_new_image_id;

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid reference: Event, User, or Guest ID not found.';
    WHEN others THEN
        RAISE EXCEPTION 'Error adding event image: %', SQLERRM;
END;
$$;


ALTER FUNCTION public.event_image_create(p_fk_event_id character varying, p_image_url text, p_fk_user_id integer, p_fk_guest_id integer) OWNER TO "default";

--
-- TOC entry 270 (class 1255 OID 40969)
-- Name: event_join_request_by_code(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.event_join_request_by_code(admincode character varying, userid character varying) RETURNS TABLE("EventId" character varying, "Status" character varying, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_id VARCHAR;
    v_admin_user_id VARCHAR;
BEGIN
    -- 1. Find Event & Admin based on the code provided
    -- We use the function name prefix to distinguish the Parameter from the Column
    SELECT fk_event_id, fk_user_id 
    INTO v_event_id, v_admin_user_id
    FROM event_admins
    WHERE admin_code = event_join_request_by_code.AdminCode;

    -- 2. Validate Code exists
    IF v_event_id IS NULL THEN
        RAISE EXCEPTION 'Invalid Event Code provided.' USING ERRCODE = 'P0001';
    END IF;

    -- 3. CHECK: IS USER THE CREATOR?
    -- If the user trying to join is already defined as the creator, STOP.
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = v_event_id AND fk_user_id = event_join_request_by_code.UserId AND is_creator = TRUE) THEN
        RETURN QUERY SELECT 
            v_event_id, 
            'Creator'::varchar, 
            'You are the creator of this event and cannot join as a guest.'::varchar;
        RETURN;
    END IF;

    -- 4. Check if already a Guest (Duplicate check)
    IF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = v_event_id AND fk_user_id = event_join_request_by_code.UserId) THEN
        RETURN QUERY SELECT 
            v_event_id, 
            'Duplicate'::varchar, 
            'You are already a guest in this event.'::varchar;
        RETURN;
    END IF;

    -- 5. Insert into Guest List
    INSERT INTO event_guests (
        fk_user_id, 
        fk_event_id, 
        fk_relation_to_user_id, 
        fk_request_status_id, 
        images_uploaded_number, 
        created_at
    )
    VALUES (
        event_join_request_by_code.UserId, 
        v_event_id, 
        v_admin_user_id, 
        1, -- Pending status
        0, 
        NOW()
    );

    RETURN QUERY SELECT 
        v_event_id, 
        'Success'::varchar, 
        'Request sent to admin successfully.'::varchar;
END;
$$;


ALTER FUNCTION public.event_join_request_by_code(admincode character varying, userid character varying) OWNER TO "default";

--
-- TOC entry 245 (class 1255 OID 24648)
-- Name: generate_random_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_random_id(size integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  characters TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  output TEXT := '';
  i INT := 0;
BEGIN
  WHILE i < size LOOP
    output := output || substr(characters, floor(random() * length(characters) + 1)::integer, 1);
    i := i + 1;
  END LOOP;
  RETURN output;
END;
$$;


ALTER FUNCTION public.generate_random_id(size integer) OWNER TO "default";

--
-- TOC entry 279 (class 1255 OID 41028)
-- Name: image_get_feed_private(character varying, character varying, integer, timestamp with time zone, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.image_get_feed_private("EventId" character varying, "ViewerUserId" character varying, "PageSize" integer DEFAULT 20, "CursorDate" timestamp with time zone DEFAULT NULL::timestamp with time zone, "CursorImageId" character varying DEFAULT NULL::character varying) RETURNS TABLE("ImageId" character varying, "ImageUrl" text, "UploaderId" character varying, "UploaderName" character varying, "UploaderProfileImageUrl" text, "IsCreator" boolean, "LikesCount" integer, "CreatedAt" timestamp with time zone, "UpdatedAt" timestamp with time zone, "IsLikedByMe" boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_creator_id VARCHAR;
    v_is_admin BOOLEAN := FALSE;
    v_is_guest BOOLEAN := FALSE;
    v_viewer_chain_types INT[] := ARRAY[]::INT[];
BEGIN
    -- 1. Get Creator ID
    SELECT fk_creator_id INTO v_creator_id FROM events WHERE pk_event_id = "EventId";

    -- 2. Security: Verify they are actually an Admin or Approved Guest
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId") THEN
        v_is_admin := TRUE;
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId" AND fk_request_status_id = 2) THEN
        v_is_guest := TRUE;
        
        -- Build the Relationship Tree Array for Privacy Rules
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

    -- 3. Block Outsiders
    IF NOT v_is_admin AND NOT v_is_guest THEN
        RAISE EXCEPTION 'Unauthorized: You are not a guest of this event.';
    END IF;

    -- 4. Fetch the Private Feed
    RETURN QUERY
    WITH ImagePrivacies AS (
        SELECT fk_event_image_id, array_agg(fk_relationship_type_id) as allowed_types
        FROM image_privacy
        GROUP BY fk_event_image_id
    )
    SELECT 
        img.pk_event_image_id AS "ImageId",
        img.image_url AS "ImageUrl",
        u.pk_user_id AS "UploaderId",
        u.name AS "UploaderName",
        u.profile_image_url AS "UploaderProfileImageUrl",
        (img.fk_user_id = v_creator_id) AS "IsCreator",
        img.likes_count AS "LikesCount",
        img.created_at AS "CreatedAt",
        img.updated_at AS "UpdatedAt", 
        (EXISTS (SELECT 1 FROM image_likes il WHERE il.fk_image_id = img.pk_event_image_id AND il.fk_user_id = "ViewerUserId")) AS "IsLikedByMe"
    FROM event_images img
    INNER JOIN users u ON img.fk_user_id = u.pk_user_id
    LEFT JOIN ImagePrivacies ip ON ip.fk_event_image_id = img.pk_event_image_id
    WHERE img.fk_event_id = "EventId"
      AND img.is_approved = TRUE
      -- Cursor Pagination
      AND ("CursorDate" IS NULL OR img.created_at < "CursorDate" OR (img.created_at = "CursorDate" AND img.pk_event_image_id < "CursorImageId"))
      -- Privacy Filter
      AND (
          v_is_admin 
          OR img.fk_user_id = "ViewerUserId" 
          OR ip.allowed_types IS NULL 
          OR (v_is_guest AND v_viewer_chain_types <@ ip.allowed_types)
      )
    ORDER BY img.created_at DESC, img.pk_event_image_id DESC
    LIMIT "PageSize";
END;
$$;


ALTER FUNCTION public.image_get_feed_private("EventId" character varying, "ViewerUserId" character varying, "PageSize" integer, "CursorDate" timestamp with time zone, "CursorImageId" character varying) OWNER TO "default";

--
-- TOC entry 287 (class 1255 OID 41030)
-- Name: image_get_feed_public(character varying, integer, timestamp with time zone, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.image_get_feed_public("EventId" character varying, "PageSize" integer DEFAULT 20, "CursorDate" timestamp with time zone DEFAULT NULL::timestamp with time zone, "CursorImageId" character varying DEFAULT NULL::character varying) RETURNS TABLE("ImageId" character varying, "ImageUrl" text, "UploaderId" character varying, "UploaderName" character varying, "UploaderProfileImageUrl" text, "IsCreator" boolean, "LikesCount" integer, "CreatedAt" timestamp with time zone, "UpdatedAt" timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_privacy_id INT;
    v_creator_id VARCHAR;
BEGIN
    -- 1. Get Event Privacy & Creator ID
    SELECT fk_event_privacy_id, fk_creator_id 
    INTO v_event_privacy_id, v_creator_id
    FROM events WHERE pk_event_id = "EventId";

    -- 2. Security: Ensure the event itself is Public (1)
    IF v_event_privacy_id != 1 THEN
        RAISE EXCEPTION 'This event is private and cannot be viewed on the public feed.';
    END IF;

    -- 3. Fetch the Public Feed
    RETURN QUERY
    SELECT 
        img.pk_event_image_id AS "ImageId",
        img.image_url AS "ImageUrl",
        u.pk_user_id AS "UploaderId",
        u.name AS "UploaderName",
        u.profile_image_url AS "UploaderProfileImageUrl",
        (img.fk_user_id = v_creator_id) AS "IsCreator",
        img.likes_count AS "LikesCount",
        img.created_at AS "CreatedAt",
        img.updated_at AS "UpdatedAt"
    FROM event_images img
    INNER JOIN users u ON img.fk_user_id = u.pk_user_id
    WHERE img.fk_event_id = "EventId"
      AND img.is_approved = TRUE
      -- Make sure this specific image has NO privacy rules attached to it
      AND NOT EXISTS (
          SELECT 1 FROM image_privacy ip WHERE ip.fk_event_image_id = img.pk_event_image_id
      )
      -- Cursor Pagination
      AND (
          "CursorDate" IS NULL 
          OR img.created_at < "CursorDate" 
          OR (img.created_at = "CursorDate" AND img.pk_event_image_id < "CursorImageId")
      )
    ORDER BY img.created_at DESC, img.pk_event_image_id DESC
    LIMIT "PageSize";
END;
$$;


ALTER FUNCTION public.image_get_feed_public("EventId" character varying, "PageSize" integer, "CursorDate" timestamp with time zone, "CursorImageId" character varying) OWNER TO "default";

--
-- TOC entry 275 (class 1255 OID 40989)
-- Name: image_toggle_like(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.image_toggle_like("UserId" character varying, "ImageId" character varying) RETURNS TABLE("IsSuccess" boolean, "Message" character varying, "IsLiked" boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_id VARCHAR;
    v_guest_id VARCHAR := NULL;
    v_already_liked BOOLEAN;
BEGIN
    -- 1. Find the Event ID associated with this image
    SELECT fk_event_id INTO v_event_id
    FROM event_images
    WHERE pk_event_image_id = "ImageId";

    IF v_event_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Image not found.'::VARCHAR, FALSE;
        RETURN;
    END IF;

    -- 2. Security Check & Get Context (Guest ID)
    -- Is the user an Admin?
    IF NOT EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = v_event_id AND fk_user_id = "UserId") THEN
        
        -- If not admin, are they an Approved Guest? (Fetch Guest ID)
        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = v_event_id AND fk_user_id = "UserId" AND fk_request_status_id = 2;

        IF v_guest_id IS NULL THEN
            RETURN QUERY SELECT FALSE, 'Unauthorized: You must be an admin or approved guest to like images.'::VARCHAR, FALSE;
            RETURN;
        END IF;
    ELSE
        -- They are an admin. See if they also happen to have a guest record.
        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = v_event_id AND fk_user_id = "UserId";
    END IF;

    -- 3. Toggle Logic (Like or Unlike)
    -- Check if the user already liked this image
    SELECT EXISTS (
        SELECT 1 FROM image_likes 
        WHERE fk_image_id = "ImageId" AND fk_user_id = "UserId"
    ) INTO v_already_liked;

    IF v_already_liked THEN
        -- UNLIKE: Delete the record
        DELETE FROM image_likes 
        WHERE fk_image_id = "ImageId" AND fk_user_id = "UserId";
        
        RETURN QUERY SELECT TRUE, 'Image unliked.'::VARCHAR, FALSE;
    ELSE
        -- LIKE: Insert a new record
        INSERT INTO image_likes (
            fk_event_id, 
            fk_image_id, 
            fk_user_id, 
            fk_guest_id, 
            created_at
        )
        VALUES (
            v_event_id, 
            "ImageId", 
            "UserId", 
            v_guest_id, 
            NOW()
        );
        
        RETURN QUERY SELECT TRUE, 'Image liked.'::VARCHAR, TRUE;
    END IF;
END;
$$;


ALTER FUNCTION public.image_toggle_like("UserId" character varying, "ImageId" character varying) OWNER TO "default";

--
-- TOC entry 282 (class 1255 OID 41010)
-- Name: prayer_delete(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prayer_delete("EventId" character varying, "PrayerId" character varying, "RequestingUserId" character varying) RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_owner_id VARCHAR;
    v_created_at TIMESTAMPTZ;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    -- 1. Find the prayer
    SELECT fk_user_id, created_at 
    INTO v_owner_id, v_created_at
    FROM event_prayers
    WHERE pk_event_prayer_id = "PrayerId" AND fk_event_id = "EventId";

    IF v_owner_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Prayer not found.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Is the requester an Admin for this event?
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId") THEN
        v_is_admin := TRUE;
    END IF;

    -- 3. Execution Logic
    IF v_is_admin THEN
        -- Admins have absolute power to delete
        DELETE FROM event_prayers WHERE pk_event_prayer_id = "PrayerId";
        RETURN QUERY SELECT TRUE, 'Message deleted by Admin.'::VARCHAR;
        
    ELSIF v_owner_id = "RequestingUserId" THEN
        -- Owner can delete, but only within 1 hour
        IF NOW() > v_created_at + INTERVAL '1 hour' THEN
            RETURN QUERY SELECT FALSE, 'Time limit exceeded. You cannot delete this message anymore.'::VARCHAR;
        ELSE
            DELETE FROM event_prayers WHERE pk_event_prayer_id = "PrayerId";
            RETURN QUERY SELECT TRUE, 'Your message was deleted.'::VARCHAR;
        END IF;
        
    ELSE
        RETURN QUERY SELECT FALSE, 'Unauthorized to delete this message.'::VARCHAR;
    END IF;
END;
$$;


ALTER FUNCTION public.prayer_delete("EventId" character varying, "PrayerId" character varying, "RequestingUserId" character varying) OWNER TO "default";

--
-- TOC entry 281 (class 1255 OID 41009)
-- Name: prayer_post_or_update(character varying, character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prayer_post_or_update("EventId" character varying, "UserId" character varying, "MessageText" text) RETURNS TABLE("PrayerId" character varying, "IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_existing_id VARCHAR;
    v_created_at TIMESTAMPTZ;
    v_guest_id VARCHAR := NULL;
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    -- 1. Security & Context Check: Is the user an Admin or Approved Guest?
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "UserId") THEN
        v_is_authorized := TRUE;
        -- Admins might not have a guest ID, which is fine now.
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2) THEN
        v_is_authorized := TRUE;
        -- Fetch their Guest ID
        SELECT pk_event_guest_id INTO v_guest_id 
        FROM event_guests 
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";
    END IF;

    IF NOT v_is_authorized THEN
        RETURN QUERY SELECT NULL::VARCHAR, FALSE, 'Unauthorized: You must be an admin or approved guest to post.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Check if they already posted a prayer
    SELECT pk_event_prayer_id, created_at 
    INTO v_existing_id, v_created_at
    FROM event_prayers
    WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

    -- 3. Update Logic (If message exists)
    IF v_existing_id IS NOT NULL THEN
        -- Strictly enforce the 1-hour rule from the original creation time
        IF NOW() > v_created_at + INTERVAL '1 hour' THEN
            RETURN QUERY SELECT v_existing_id, FALSE, 'Time limit exceeded. You can only edit your message within 1 hour of posting.'::VARCHAR;
            RETURN;
        END IF;

        UPDATE event_prayers
        SET prayer_message = TRIM("MessageText")
        WHERE pk_event_prayer_id = v_existing_id;

        RETURN QUERY SELECT v_existing_id, TRUE, 'Prayer updated successfully.'::VARCHAR;
        
    -- 4. Insert Logic (If message does not exist)
    ELSE
        INSERT INTO event_prayers (
            fk_event_id, 
            fk_user_id, 
            fk_guest_id, 
            prayer_message, 
            created_at
        )
        VALUES (
            "EventId", 
            "UserId", 
            v_guest_id, 
            TRIM("MessageText"), 
            NOW()
        )
        RETURNING pk_event_prayer_id INTO v_existing_id;

        RETURN QUERY SELECT v_existing_id, TRUE, 'Prayer posted successfully.'::VARCHAR;
    END IF;
END;
$$;


ALTER FUNCTION public.prayer_post_or_update("EventId" character varying, "UserId" character varying, "MessageText" text) OWNER TO "default";

--
-- TOC entry 283 (class 1255 OID 41014)
-- Name: prayers_get(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prayers_get("EventId" character varying, "ViewerUserId" character varying) RETURNS TABLE("PrayerId" character varying, "UserId" character varying, "UserName" character varying, "ProfileImageUrl" text, "PrayerMessage" text, "CreatedAt" timestamp with time zone, "IsMyMessage" boolean, "CanEdit" boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_event_privacy_id INT;
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    -- 1. Security: Check Event Privacy (Public vs Guests Only)
    SELECT fk_event_privacy_id INTO v_event_privacy_id
    FROM events WHERE pk_event_id = "EventId";

    -- Are they related to the event?
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId") OR 
       EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "ViewerUserId" AND fk_request_status_id = 2) THEN
        v_is_authorized := TRUE;
    END IF;

    -- Block if private and not related
    IF v_event_privacy_id = 2 AND NOT v_is_authorized THEN
        RAISE EXCEPTION 'This event is private. Only approved guests can view the prayer wall.';
    END IF;

    -- 2. Return the Wall Data
    RETURN QUERY
    SELECT 
        ep.pk_event_prayer_id AS "PrayerId",
        u.pk_user_id AS "UserId",
        u.name AS "UserName",
        u.profile_image_url AS "ProfileImageUrl",
        ep.prayer_message AS "PrayerMessage",
        ep.created_at AS "CreatedAt",
        
        -- UI Helper: Is this the viewer's own message?
        (u.pk_user_id = "ViewerUserId") AS "IsMyMessage",
        
        -- UI Helper: Can they still edit/delete it? (Under 1 hour old)
        (u.pk_user_id = "ViewerUserId" AND NOW() <= ep.created_at + INTERVAL '1 hour') AS "CanEdit"
        
    FROM event_prayers ep
    INNER JOIN users u ON ep.fk_user_id = u.pk_user_id
    WHERE ep.fk_event_id = "EventId"
    ORDER BY ep.created_at DESC; -- Newest messages at the top
END;
$$;


ALTER FUNCTION public.prayers_get("EventId" character varying, "ViewerUserId" character varying) OWNER TO "default";

--
-- TOC entry 255 (class 1255 OID 40982)
-- Name: ref_get_colors(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ref_get_colors() RETURNS TABLE("ColorId" integer, "ColorName" character varying, "ColorCode" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_color_id, 
        color_name, 
        color_code 
    FROM 
        colors
    ORDER BY 
        pk_color_id ASC;
END;
$$;


ALTER FUNCTION public.ref_get_colors() OWNER TO "default";

--
-- TOC entry 284 (class 1255 OID 41015)
-- Name: ref_get_event_privacy(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ref_get_event_privacy() RETURNS TABLE("PrivacyId" integer, "PrivacyName" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_event_privacy_id, 
        privacy_name 
    FROM event_privacy
    ORDER BY pk_event_privacy_id ASC;
END;
$$;


ALTER FUNCTION public.ref_get_event_privacy() OWNER TO "default";

--
-- TOC entry 250 (class 1255 OID 40973)
-- Name: ref_get_relationship_types(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ref_get_relationship_types() RETURNS TABLE("RelationshipTypeId" integer, "RelationshipTypeName" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_relationship_type_id, 
        relationship_type_name 
    FROM 
        relationship_types
    ORDER BY 
        pk_relationship_type_id ASC;
END;
$$;


ALTER FUNCTION public.ref_get_relationship_types() OWNER TO "default";

--
-- TOC entry 253 (class 1255 OID 40981)
-- Name: ref_get_relationships_by_type(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ref_get_relationships_by_type("InRelationshipTypeId" integer) RETURNS TABLE("RelationshipId" integer, "RelationshipTypeId" integer, "RelationshipName" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_relationship_id,
        fk_relationship_type_id, 
        relationship_name 
    FROM 
        relationships 
    WHERE 
        fk_relationship_type_id = "InRelationshipTypeId"
    ORDER BY 
        relationship_name ASC;
END;
$$;


ALTER FUNCTION public.ref_get_relationships_by_type("InRelationshipTypeId" integer) OWNER TO "default";

--
-- TOC entry 251 (class 1255 OID 40974)
-- Name: ref_get_sub_categories(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ref_get_sub_categories("CategoryId" integer) RETURNS TABLE("SubCategoryId" integer, "SubCategoryName" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_sub_category_id, 
        sub_category_name 
    FROM 
        sub_categories 
    WHERE 
        fk_event_category_id = "CategoryId"
    ORDER BY 
        sub_category_name ASC;
END;
$$;


ALTER FUNCTION public.ref_get_sub_categories("CategoryId" integer) OWNER TO "default";

--
-- TOC entry 269 (class 1255 OID 40963)
-- Name: sub_category_get_by_category_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sub_category_get_by_category_id(p_category_id integer) RETURNS TABLE("SubCategoryId" integer, "EventCategoryId" integer, "SubCategoryName" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pk_sub_category_id, 
        fk_event_category_id, 
        sub_category_name 
    FROM 
        sub_categories
    WHERE 
        fk_event_category_id = p_category_id;
END;
$$;


ALTER FUNCTION public.sub_category_get_by_category_id(p_category_id integer) OWNER TO "default";

--
-- TOC entry 246 (class 1255 OID 24929)
-- Name: update_guest_image_count(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_guest_image_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE event_guests
        SET images_uploaded_number = images_uploaded_number + 1
        WHERE pk_event_guest_id = NEW.fk_guest_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE event_guests
        SET images_uploaded_number = GREATEST(images_uploaded_number - 1, 0) -- Prevent negative numbers
        WHERE pk_event_guest_id = OLD.fk_guest_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_guest_image_count() OWNER TO "default";

--
-- TOC entry 247 (class 1255 OID 25022)
-- Name: update_image_like_count(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_image_like_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE event_images
        SET likes_count = likes_count + 1
        WHERE pk_event_image_id = NEW.fk_image_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE event_images
        SET likes_count = GREATEST(likes_count - 1, 0)
        WHERE pk_event_image_id = OLD.fk_image_id;
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_image_like_count() OWNER TO "default";

--
-- TOC entry 249 (class 1255 OID 25028)
-- Name: user_check_if_exist(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_check_if_exist(p_email character varying) RETURNS TABLE("IsExist" boolean, "UserId" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id VARCHAR(8);
BEGIN
    -- 1. Optimized Lookup
    -- We select the ID into a variable. 
    SELECT pk_user_id INTO v_user_id 
    FROM users 
    WHERE email = p_email;

    -- 2. Return Logic
    IF v_user_id IS NOT NULL THEN
        -- Found: Return True and the ID
        RETURN QUERY SELECT TRUE, v_user_id;
    ELSE
        -- Not Found: Return False and Null
        RETURN QUERY SELECT FALSE, CAST(NULL AS VARCHAR(8));
    END IF;
END;
$$;


ALTER FUNCTION public.user_check_if_exist(p_email character varying) OWNER TO "default";

--
-- TOC entry 248 (class 1255 OID 25027)
-- Name: user_create(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_create(p_name character varying, p_email character varying, p_phone_number character varying) RETURNS TABLE("UserId" character varying, "RoleName" character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE 
    _user_role_id INT;
    _role_name_constant VARCHAR(50) := 'User';
    _generated_id VARCHAR(8);
BEGIN
    -- 1. Input Sanitization
    p_email := LOWER(TRIM(p_email));
    p_name := TRIM(p_name);

    -- 2. Get Role ID
    SELECT pk_role_id INTO _user_role_id 
    FROM roles 
    WHERE role_name = _role_name_constant;

    IF _user_role_id IS NULL THEN
        RAISE EXCEPTION 'Default role "%" not found.', _role_name_constant;
    END IF;

    -- 3. Insert
    INSERT INTO users (name, email, phone_number, fk_role_id) 
    VALUES (p_name, p_email, p_phone_number, _user_role_id)
    RETURNING pk_user_id INTO _generated_id;

    -- 4. ASSIGN VALUES TO THE RETURN VARIABLES
    -- Notice we assign directly to the names defined in RETURNS TABLE
    "UserId" := _generated_id;
    "RoleName" := _role_name_constant;
    
    RETURN NEXT; -- Pushes the row {"UserId": "101", "RoleName": "User"}
END;
$$;


ALTER FUNCTION public.user_create(p_name character varying, p_email character varying, p_phone_number character varying) OWNER TO "default";

--
-- TOC entry 254 (class 1255 OID 25031)
-- Name: user_get_by_email(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_get_by_email(p_user_email character varying) RETURNS TABLE("UserId" character varying, "Name" character varying, "Email" character varying, "PhoneNumber" character varying, "RoleName" character varying, "CreatedAt" date, "UpdatedAt" date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.pk_user_id,
        u.name,
        u.email,
        u.phone_number,
        r.role_name,          -- Fetch the name, not the ID
        u.created_at::DATE,   -- Cast Timestamp to Date
        u.updated_at::DATE    -- Cast Timestamp to Date
    FROM users u
    -- INNER JOIN ensures we only get users who have a valid role
    INNER JOIN roles r ON u.fk_role_id = r.pk_role_id
    WHERE u.email = p_user_email; -- FIXED: Compare Email column to Email parameter
END;
$$;


ALTER FUNCTION public.user_get_by_email(p_user_email character varying) OWNER TO "default";

--
-- TOC entry 252 (class 1255 OID 25029)
-- Name: user_get_by_id(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_get_by_id(_user_id character varying) RETURNS TABLE("UserId" character varying, "Name" character varying, "Email" character varying, "PhoneNumber" character varying, "RoleName" character varying, "CreatedAt" date, "UpdatedAt" date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.pk_user_id,
        u.name,
        u.email,
        u.phone_number,
        r.role_name,          -- Fetch the name, not the ID
        u.created_at::DATE,   -- Cast Timestamp to Date
        u.updated_at::DATE    -- Cast Timestamp to Date
    FROM users u
    -- INNER JOIN ensures we only get users who have a valid role
    INNER JOIN roles r ON u.fk_role_id = r.pk_role_id
    WHERE u.pk_user_id = _user_id;
END;
$$;


ALTER FUNCTION public.user_get_by_id(_user_id character varying) OWNER TO "default";

--
-- TOC entry 274 (class 1255 OID 40988)
-- Name: user_update_profile(character varying, character varying, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.user_update_profile("UserId" character varying, "NewName" character varying, "NewProfileImageUrl" text) RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- 1. Input Validation: Ensure the name is not empty
    IF "NewName" IS NULL OR length(trim("NewName")) = 0 THEN
        RETURN QUERY SELECT FALSE, 'Name cannot be empty.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Update the User Record
    UPDATE users
    SET 
        name = TRIM("NewName"),
        profile_image_url = TRIM("NewProfileImageUrl"), -- Can be NULL if they remove their picture
        updated_at = NOW()
    WHERE pk_user_id = "UserId";

    -- 3. Check if the update was successful
    IF FOUND THEN
        RETURN QUERY SELECT TRUE, 'Profile updated successfully.'::VARCHAR;
    ELSE
        RETURN QUERY SELECT FALSE, 'User not found.'::VARCHAR;
    END IF;
END;
$$;


ALTER FUNCTION public.user_update_profile("UserId" character varying, "NewName" character varying, "NewProfileImageUrl" text) OWNER TO "default";

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 235 (class 1259 OID 24844)
-- Name: colors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.colors (
    pk_color_id integer NOT NULL,
    color_name character varying(50) NOT NULL,
    color_code character varying(10) NOT NULL
);


ALTER TABLE public.colors OWNER TO "default";

--
-- TOC entry 234 (class 1259 OID 24843)
-- Name: colors_pk_color_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.colors ALTER COLUMN pk_color_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.colors_pk_color_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 24857)
-- Name: event_admins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_admins (
    pk_event_admin_id character varying(8) DEFAULT public.generate_random_id(8) NOT NULL,
    fk_user_id character varying(8) NOT NULL,
    fk_event_id character varying(8) NOT NULL,
    admin_code character varying(6) DEFAULT public.generate_random_id(6) NOT NULL,
    is_creator boolean DEFAULT false,
    fk_color_id integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.event_admins OWNER TO "default";

--
-- TOC entry 223 (class 1259 OID 24673)
-- Name: event_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_categories (
    pk_event_category_id integer NOT NULL,
    event_category_name character varying(100) NOT NULL
);


ALTER TABLE public.event_categories OWNER TO "default";

--
-- TOC entry 222 (class 1259 OID 24672)
-- Name: event_categories_pk_event_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.event_categories ALTER COLUMN pk_event_category_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.event_categories_pk_event_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 233 (class 1259 OID 24793)
-- Name: event_guests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_guests (
    pk_event_guest_id character varying(8) DEFAULT public.generate_random_id(8) NOT NULL,
    fk_user_id character varying(8) NOT NULL,
    fk_event_id character varying(8) NOT NULL,
    fk_relationship_type_id integer,
    fk_relationship_id integer,
    fk_relation_to_user_id character varying(8),
    fk_request_status_id integer DEFAULT 1 NOT NULL,
    images_uploaded_number integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT event_guests_images_uploaded_number_check CHECK ((images_uploaded_number >= 0))
);


ALTER TABLE public.event_guests OWNER TO "default";

--
-- TOC entry 237 (class 1259 OID 24897)
-- Name: event_images; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_images (
    pk_event_image_id character varying(8) DEFAULT public.generate_random_id(8) NOT NULL,
    fk_user_id character varying(8) NOT NULL,
    fk_guest_id character varying(8),
    fk_event_id character varying(8) NOT NULL,
    image_url text NOT NULL,
    is_approved boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    likes_count integer DEFAULT 0,
    CONSTRAINT event_images_likes_count_check CHECK ((likes_count >= 0))
);


ALTER TABLE public.event_images OWNER TO "default";

--
-- TOC entry 240 (class 1259 OID 24954)
-- Name: event_prayers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_prayers (
    pk_event_prayer_id character varying(8) DEFAULT public.generate_random_id(8) NOT NULL,
    fk_event_id character varying(8) NOT NULL,
    fk_user_id character varying(8) NOT NULL,
    fk_guest_id character varying(8),
    prayer_message text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.event_prayers OWNER TO "default";

--
-- TOC entry 244 (class 1259 OID 40991)
-- Name: event_privacy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_privacy (
    pk_event_privacy_id integer NOT NULL,
    privacy_name character varying(50) NOT NULL
);


ALTER TABLE public.event_privacy OWNER TO "default";

--
-- TOC entry 243 (class 1259 OID 40990)
-- Name: event_privacy_pk_event_privacy_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.event_privacy ALTER COLUMN pk_event_privacy_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.event_privacy_pk_event_privacy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 24719)
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events (
    pk_event_id character varying(8) DEFAULT public.generate_random_id(8) NOT NULL,
    fk_event_category_id integer NOT NULL,
    fk_sub_category_id integer,
    event_title character varying(255) NOT NULL,
    tag_line character varying(30),
    expected_guest_number integer,
    venue text NOT NULL,
    event_date_time timestamp with time zone NOT NULL,
    fk_creator_id character varying(8) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    event_cover_image_url text,
    fk_event_privacy_id integer DEFAULT 2 NOT NULL,
    CONSTRAINT events_expected_guest_number_check CHECK ((expected_guest_number > 0))
);


ALTER TABLE public.events OWNER TO "default";

--
-- TOC entry 242 (class 1259 OID 24986)
-- Name: image_likes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.image_likes (
    pk_image_like_id integer NOT NULL,
    fk_event_id character varying(8) NOT NULL,
    fk_image_id character varying(8) NOT NULL,
    fk_user_id character varying(8) NOT NULL,
    fk_guest_id character varying(8) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.image_likes OWNER TO "default";

--
-- TOC entry 241 (class 1259 OID 24985)
-- Name: image_likes_pk_image_like_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.image_likes ALTER COLUMN pk_image_like_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.image_likes_pk_image_like_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 24932)
-- Name: image_privacy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.image_privacy (
    pk_image_privacy_id integer NOT NULL,
    fk_event_image_id character varying(8) NOT NULL,
    fk_relationship_type_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.image_privacy OWNER TO "default";

--
-- TOC entry 238 (class 1259 OID 24931)
-- Name: image_privacy_pk_image_privacy_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.image_privacy ALTER COLUMN pk_image_privacy_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.image_privacy_pk_image_privacy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 24754)
-- Name: relationship_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relationship_types (
    pk_relationship_type_id integer NOT NULL,
    relationship_type_name character varying(50) NOT NULL
);


ALTER TABLE public.relationship_types OWNER TO "default";

--
-- TOC entry 227 (class 1259 OID 24753)
-- Name: relationship_types_pk_relationship_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.relationship_types ALTER COLUMN pk_relationship_type_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.relationship_types_pk_relationship_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 24766)
-- Name: relationships; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.relationships (
    pk_relationship_id integer NOT NULL,
    fk_relationship_type_id integer NOT NULL,
    relationship_name character varying(50) NOT NULL
);


ALTER TABLE public.relationships OWNER TO "default";

--
-- TOC entry 229 (class 1259 OID 24765)
-- Name: relationships_pk_relationship_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.relationships ALTER COLUMN pk_relationship_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.relationships_pk_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 24784)
-- Name: request_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.request_statuses (
    pk_request_status_id integer NOT NULL,
    status_name character varying(50) NOT NULL
);


ALTER TABLE public.request_statuses OWNER TO "default";

--
-- TOC entry 231 (class 1259 OID 24783)
-- Name: request_statuses_pk_request_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.request_statuses ALTER COLUMN pk_request_status_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.request_statuses_pk_request_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 24588)
-- Name: roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.roles (
    pk_role_id integer NOT NULL,
    role_name character varying(100) NOT NULL
);


ALTER TABLE public.roles OWNER TO "default";

--
-- TOC entry 219 (class 1259 OID 24587)
-- Name: roles_pk_role_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.roles ALTER COLUMN pk_role_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.roles_pk_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 225 (class 1259 OID 24702)
-- Name: sub_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sub_categories (
    pk_sub_category_id integer NOT NULL,
    fk_event_category_id integer NOT NULL,
    sub_category_name character varying(100) NOT NULL
);


ALTER TABLE public.sub_categories OWNER TO "default";

--
-- TOC entry 224 (class 1259 OID 24701)
-- Name: sub_categories_pk_sub_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.sub_categories ALTER COLUMN pk_sub_category_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.sub_categories_pk_sub_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 221 (class 1259 OID 24649)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    pk_user_id character varying(8) DEFAULT public.generate_random_id(8) NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone_number character varying(20),
    fk_role_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    profile_image_url text
);


ALTER TABLE public.users OWNER TO "default";

--
-- TOC entry 5066 (class 2606 OID 40997)
-- Name: event_privacy event_privacy_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_privacy
    ADD CONSTRAINT event_privacy_pkey PRIMARY KEY (pk_event_privacy_id);


--
-- TOC entry 5068 (class 2606 OID 40999)
-- Name: event_privacy event_privacy_privacy_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_privacy
    ADD CONSTRAINT event_privacy_privacy_name_key UNIQUE (privacy_name);


--
-- TOC entry 5035 (class 2606 OID 24851)
-- Name: colors pk_colors; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colors
    ADD CONSTRAINT pk_colors PRIMARY KEY (pk_color_id);


--
-- TOC entry 5043 (class 2606 OID 24872)
-- Name: event_admins pk_event_admins; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_admins
    ADD CONSTRAINT pk_event_admins PRIMARY KEY (pk_event_admin_id);


--
-- TOC entry 4998 (class 2606 OID 24679)
-- Name: event_categories pk_event_categories; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT pk_event_categories PRIMARY KEY (pk_event_category_id);


--
-- TOC entry 5031 (class 2606 OID 24807)
-- Name: event_guests pk_event_guests; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT pk_event_guests PRIMARY KEY (pk_event_guest_id);


--
-- TOC entry 5050 (class 2606 OID 24911)
-- Name: event_images pk_event_images; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_images
    ADD CONSTRAINT pk_event_images PRIMARY KEY (pk_event_image_id);


--
-- TOC entry 5059 (class 2606 OID 24967)
-- Name: event_prayers pk_event_prayers; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_prayers
    ADD CONSTRAINT pk_event_prayers PRIMARY KEY (pk_event_prayer_id);


--
-- TOC entry 5011 (class 2606 OID 24734)
-- Name: events pk_events_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT pk_events_id PRIMARY KEY (pk_event_id);


--
-- TOC entry 5062 (class 2606 OID 24996)
-- Name: image_likes pk_image_likes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_likes
    ADD CONSTRAINT pk_image_likes PRIMARY KEY (pk_image_like_id);


--
-- TOC entry 5053 (class 2606 OID 24940)
-- Name: image_privacy pk_image_privacy; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_privacy
    ADD CONSTRAINT pk_image_privacy PRIMARY KEY (pk_image_privacy_id);


--
-- TOC entry 5014 (class 2606 OID 24760)
-- Name: relationship_types pk_relationship_types; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relationship_types
    ADD CONSTRAINT pk_relationship_types PRIMARY KEY (pk_relationship_type_id);


--
-- TOC entry 5020 (class 2606 OID 24773)
-- Name: relationships pk_relationships; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relationships
    ADD CONSTRAINT pk_relationships PRIMARY KEY (pk_relationship_id);


--
-- TOC entry 5024 (class 2606 OID 24790)
-- Name: request_statuses pk_request_statuses; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statuses
    ADD CONSTRAINT pk_request_statuses PRIMARY KEY (pk_request_status_id);


--
-- TOC entry 4987 (class 2606 OID 24594)
-- Name: roles pk_roles_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT pk_roles_id PRIMARY KEY (pk_role_id);


--
-- TOC entry 5004 (class 2606 OID 24709)
-- Name: sub_categories pk_sub_categories; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sub_categories
    ADD CONSTRAINT pk_sub_categories PRIMARY KEY (pk_sub_category_id);


--
-- TOC entry 4993 (class 2606 OID 24662)
-- Name: users pk_users_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT pk_users_id PRIMARY KEY (pk_user_id);


--
-- TOC entry 5037 (class 2606 OID 24855)
-- Name: colors uq_color_code; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colors
    ADD CONSTRAINT uq_color_code UNIQUE (color_code);


--
-- TOC entry 5039 (class 2606 OID 24853)
-- Name: colors uq_color_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.colors
    ADD CONSTRAINT uq_color_name UNIQUE (color_name);


--
-- TOC entry 5045 (class 2606 OID 24874)
-- Name: event_admins uq_event_admin_user_event; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_admins
    ADD CONSTRAINT uq_event_admin_user_event UNIQUE (fk_user_id, fk_event_id);


--
-- TOC entry 5000 (class 2606 OID 24681)
-- Name: event_categories uq_event_category_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT uq_event_category_name UNIQUE (event_category_name);


--
-- TOC entry 5033 (class 2606 OID 24809)
-- Name: event_guests uq_event_guest_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT uq_event_guest_unique UNIQUE (fk_user_id, fk_event_id);


--
-- TOC entry 5064 (class 2606 OID 24998)
-- Name: image_likes uq_like_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_likes
    ADD CONSTRAINT uq_like_unique UNIQUE (fk_user_id, fk_image_id);


--
-- TOC entry 5055 (class 2606 OID 24942)
-- Name: image_privacy uq_privacy_rule; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_privacy
    ADD CONSTRAINT uq_privacy_rule UNIQUE (fk_event_image_id, fk_relationship_type_id);


--
-- TOC entry 5022 (class 2606 OID 24775)
-- Name: relationships uq_relationship_per_type; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relationships
    ADD CONSTRAINT uq_relationship_per_type UNIQUE (fk_relationship_type_id, relationship_name);


--
-- TOC entry 5016 (class 2606 OID 24762)
-- Name: relationship_types uq_relationship_type_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relationship_types
    ADD CONSTRAINT uq_relationship_type_name UNIQUE (relationship_type_name);


--
-- TOC entry 4989 (class 2606 OID 24596)
-- Name: roles uq_role_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT uq_role_name UNIQUE (role_name);


--
-- TOC entry 5026 (class 2606 OID 24792)
-- Name: request_statuses uq_status_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statuses
    ADD CONSTRAINT uq_status_name UNIQUE (status_name);


--
-- TOC entry 5006 (class 2606 OID 24711)
-- Name: sub_categories uq_sub_category_per_parent; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sub_categories
    ADD CONSTRAINT uq_sub_category_per_parent UNIQUE (fk_event_category_id, sub_category_name);


--
-- TOC entry 4995 (class 2606 OID 24664)
-- Name: users uq_user_email; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT uq_user_email UNIQUE (email);


--
-- TOC entry 5056 (class 1259 OID 24984)
-- Name: guest_id_event_prayers_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX guest_id_event_prayers_event ON public.event_prayers USING btree (fk_guest_id);


--
-- TOC entry 5040 (class 1259 OID 24896)
-- Name: idx_event_admins_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_admins_code ON public.event_admins USING btree (admin_code);


--
-- TOC entry 5041 (class 1259 OID 24895)
-- Name: idx_event_admins_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_admins_event ON public.event_admins USING btree (fk_event_id);


--
-- TOC entry 4996 (class 1259 OID 24682)
-- Name: idx_event_categories_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_categories_name ON public.event_categories USING btree (event_category_name);


--
-- TOC entry 5027 (class 1259 OID 24840)
-- Name: idx_event_guests_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_guests_event ON public.event_guests USING btree (fk_event_id);


--
-- TOC entry 5028 (class 1259 OID 24842)
-- Name: idx_event_guests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_guests_status ON public.event_guests USING btree (fk_request_status_id);


--
-- TOC entry 5029 (class 1259 OID 24841)
-- Name: idx_event_guests_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_guests_user ON public.event_guests USING btree (fk_user_id);


--
-- TOC entry 5046 (class 1259 OID 24927)
-- Name: idx_event_images_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_images_event ON public.event_images USING btree (fk_event_id);


--
-- TOC entry 5047 (class 1259 OID 24928)
-- Name: idx_event_images_guest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_images_guest ON public.event_images USING btree (fk_guest_id);


--
-- TOC entry 5048 (class 1259 OID 32771)
-- Name: idx_event_images_pagination; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_images_pagination ON public.event_images USING btree (fk_event_id, created_at DESC, pk_event_image_id);


--
-- TOC entry 5057 (class 1259 OID 24983)
-- Name: idx_event_prayers_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_event_prayers_event ON public.event_prayers USING btree (fk_event_id);


--
-- TOC entry 5007 (class 1259 OID 24750)
-- Name: idx_events_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_category ON public.events USING btree (fk_event_category_id);


--
-- TOC entry 5008 (class 1259 OID 24751)
-- Name: idx_events_creator; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_creator ON public.events USING btree (fk_creator_id);


--
-- TOC entry 5009 (class 1259 OID 24752)
-- Name: idx_events_date_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_date_time ON public.events USING btree (event_date_time);


--
-- TOC entry 5051 (class 1259 OID 24953)
-- Name: idx_image_privacy_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_image_privacy_lookup ON public.image_privacy USING btree (fk_event_image_id, fk_relationship_type_id);


--
-- TOC entry 5060 (class 1259 OID 25019)
-- Name: idx_likes_image; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_likes_image ON public.image_likes USING btree (fk_image_id);


--
-- TOC entry 5012 (class 1259 OID 24763)
-- Name: idx_relationship_types_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_relationship_types_name ON public.relationship_types USING btree (relationship_type_name);


--
-- TOC entry 5017 (class 1259 OID 24781)
-- Name: idx_relationships_fk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_relationships_fk ON public.relationships USING btree (fk_relationship_type_id);


--
-- TOC entry 5018 (class 1259 OID 24782)
-- Name: idx_relationships_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_relationships_name ON public.relationships USING btree (relationship_name);


--
-- TOC entry 4984 (class 1259 OID 24597)
-- Name: idx_roles_role_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_roles_role_id ON public.roles USING btree (pk_role_id);


--
-- TOC entry 4985 (class 1259 OID 24598)
-- Name: idx_roles_role_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_roles_role_name ON public.roles USING btree (role_name);


--
-- TOC entry 5001 (class 1259 OID 24717)
-- Name: idx_sub_categories_fk; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sub_categories_fk ON public.sub_categories USING btree (fk_event_category_id);


--
-- TOC entry 5002 (class 1259 OID 24718)
-- Name: idx_sub_categories_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sub_categories_name ON public.sub_categories USING btree (sub_category_name);


--
-- TOC entry 4990 (class 1259 OID 24670)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email) WITH (fillfactor='100', deduplicate_items='true');


--
-- TOC entry 4991 (class 1259 OID 24671)
-- Name: idx_users_fk_role_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_fk_role_id ON public.users USING btree (fk_role_id) WITH (fillfactor='100', deduplicate_items='true');


--
-- TOC entry 5097 (class 2620 OID 24930)
-- Name: event_images trg_auto_count_images; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auto_count_images AFTER INSERT OR DELETE ON public.event_images FOR EACH ROW EXECUTE FUNCTION public.update_guest_image_count();


--
-- TOC entry 5098 (class 2620 OID 25023)
-- Name: image_likes trg_auto_count_likes; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auto_count_likes AFTER INSERT OR DELETE ON public.image_likes FOR EACH ROW EXECUTE FUNCTION public.update_image_like_count();


--
-- TOC entry 5082 (class 2606 OID 24890)
-- Name: event_admins fk_event_admins_color; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_admins
    ADD CONSTRAINT fk_event_admins_color FOREIGN KEY (fk_color_id) REFERENCES public.colors(pk_color_id) ON DELETE SET DEFAULT;


--
-- TOC entry 5083 (class 2606 OID 24885)
-- Name: event_admins fk_event_admins_event; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_admins
    ADD CONSTRAINT fk_event_admins_event FOREIGN KEY (fk_event_id) REFERENCES public.events(pk_event_id) ON DELETE CASCADE;


--
-- TOC entry 5084 (class 2606 OID 24875)
-- Name: event_admins fk_event_admins_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_admins
    ADD CONSTRAINT fk_event_admins_user FOREIGN KEY (fk_user_id) REFERENCES public.users(pk_user_id) ON DELETE CASCADE;


--
-- TOC entry 5076 (class 2606 OID 24815)
-- Name: event_guests fk_event_guests_event; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT fk_event_guests_event FOREIGN KEY (fk_event_id) REFERENCES public.events(pk_event_id) ON DELETE CASCADE;


--
-- TOC entry 5077 (class 2606 OID 24820)
-- Name: event_guests fk_event_guests_rel_type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT fk_event_guests_rel_type FOREIGN KEY (fk_relationship_type_id) REFERENCES public.relationship_types(pk_relationship_type_id) ON DELETE RESTRICT;


--
-- TOC entry 5078 (class 2606 OID 24830)
-- Name: event_guests fk_event_guests_relation_to; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT fk_event_guests_relation_to FOREIGN KEY (fk_relation_to_user_id) REFERENCES public.users(pk_user_id) ON DELETE SET NULL;


--
-- TOC entry 5079 (class 2606 OID 24825)
-- Name: event_guests fk_event_guests_relationship; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT fk_event_guests_relationship FOREIGN KEY (fk_relationship_id) REFERENCES public.relationships(pk_relationship_id) ON DELETE RESTRICT;


--
-- TOC entry 5080 (class 2606 OID 24835)
-- Name: event_guests fk_event_guests_status; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT fk_event_guests_status FOREIGN KEY (fk_request_status_id) REFERENCES public.request_statuses(pk_request_status_id) ON DELETE RESTRICT;


--
-- TOC entry 5081 (class 2606 OID 24810)
-- Name: event_guests fk_event_guests_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_guests
    ADD CONSTRAINT fk_event_guests_user FOREIGN KEY (fk_user_id) REFERENCES public.users(pk_user_id) ON DELETE CASCADE;


--
-- TOC entry 5085 (class 2606 OID 24922)
-- Name: event_images fk_event_images_event; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_images
    ADD CONSTRAINT fk_event_images_event FOREIGN KEY (fk_event_id) REFERENCES public.events(pk_event_id) ON DELETE CASCADE;


--
-- TOC entry 5086 (class 2606 OID 41016)
-- Name: event_images fk_event_images_guest; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_images
    ADD CONSTRAINT fk_event_images_guest FOREIGN KEY (fk_guest_id) REFERENCES public.event_guests(pk_event_guest_id) ON DELETE SET NULL;


--
-- TOC entry 5087 (class 2606 OID 24912)
-- Name: event_images fk_event_images_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_images
    ADD CONSTRAINT fk_event_images_user FOREIGN KEY (fk_user_id) REFERENCES public.users(pk_user_id) ON DELETE CASCADE;


--
-- TOC entry 5090 (class 2606 OID 24968)
-- Name: event_prayers fk_event_prayers_event; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_prayers
    ADD CONSTRAINT fk_event_prayers_event FOREIGN KEY (fk_event_id) REFERENCES public.events(pk_event_id) ON DELETE CASCADE;


--
-- TOC entry 5091 (class 2606 OID 41021)
-- Name: event_prayers fk_event_prayers_guest; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_prayers
    ADD CONSTRAINT fk_event_prayers_guest FOREIGN KEY (fk_guest_id) REFERENCES public.event_guests(pk_event_guest_id) ON DELETE SET NULL;


--
-- TOC entry 5092 (class 2606 OID 24973)
-- Name: event_prayers fk_event_prayers_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_prayers
    ADD CONSTRAINT fk_event_prayers_user FOREIGN KEY (fk_user_id) REFERENCES public.users(pk_user_id) ON DELETE CASCADE;


--
-- TOC entry 5071 (class 2606 OID 24735)
-- Name: events fk_events_category; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_events_category FOREIGN KEY (fk_event_category_id) REFERENCES public.event_categories(pk_event_category_id) ON DELETE RESTRICT;


--
-- TOC entry 5072 (class 2606 OID 24745)
-- Name: events fk_events_creator; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_events_creator FOREIGN KEY (fk_creator_id) REFERENCES public.users(pk_user_id) ON DELETE RESTRICT;


--
-- TOC entry 5073 (class 2606 OID 41002)
-- Name: events fk_events_privacy; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_events_privacy FOREIGN KEY (fk_event_privacy_id) REFERENCES public.event_privacy(pk_event_privacy_id) ON DELETE RESTRICT;


--
-- TOC entry 5074 (class 2606 OID 24740)
-- Name: events fk_events_sub_category; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_events_sub_category FOREIGN KEY (fk_sub_category_id) REFERENCES public.sub_categories(pk_sub_category_id) ON DELETE RESTRICT;


--
-- TOC entry 5093 (class 2606 OID 24999)
-- Name: image_likes fk_likes_event; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_likes
    ADD CONSTRAINT fk_likes_event FOREIGN KEY (fk_event_id) REFERENCES public.events(pk_event_id) ON DELETE CASCADE;


--
-- TOC entry 5094 (class 2606 OID 25014)
-- Name: image_likes fk_likes_guest; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_likes
    ADD CONSTRAINT fk_likes_guest FOREIGN KEY (fk_guest_id) REFERENCES public.event_guests(pk_event_guest_id) ON DELETE CASCADE;


--
-- TOC entry 5095 (class 2606 OID 25004)
-- Name: image_likes fk_likes_image; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_likes
    ADD CONSTRAINT fk_likes_image FOREIGN KEY (fk_image_id) REFERENCES public.event_images(pk_event_image_id) ON DELETE CASCADE;


--
-- TOC entry 5096 (class 2606 OID 25009)
-- Name: image_likes fk_likes_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_likes
    ADD CONSTRAINT fk_likes_user FOREIGN KEY (fk_user_id) REFERENCES public.users(pk_user_id) ON DELETE CASCADE;


--
-- TOC entry 5088 (class 2606 OID 24943)
-- Name: image_privacy fk_privacy_image; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_privacy
    ADD CONSTRAINT fk_privacy_image FOREIGN KEY (fk_event_image_id) REFERENCES public.event_images(pk_event_image_id) ON DELETE CASCADE;


--
-- TOC entry 5089 (class 2606 OID 24948)
-- Name: image_privacy fk_privacy_rel_type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.image_privacy
    ADD CONSTRAINT fk_privacy_rel_type FOREIGN KEY (fk_relationship_type_id) REFERENCES public.relationship_types(pk_relationship_type_id) ON DELETE CASCADE;


--
-- TOC entry 5075 (class 2606 OID 24776)
-- Name: relationships fk_relationships_type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.relationships
    ADD CONSTRAINT fk_relationships_type FOREIGN KEY (fk_relationship_type_id) REFERENCES public.relationship_types(pk_relationship_type_id) ON DELETE RESTRICT;


--
-- TOC entry 5070 (class 2606 OID 24712)
-- Name: sub_categories fk_sub_categories_parent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sub_categories
    ADD CONSTRAINT fk_sub_categories_parent FOREIGN KEY (fk_event_category_id) REFERENCES public.event_categories(pk_event_category_id) ON DELETE RESTRICT;


--
-- TOC entry 5069 (class 2606 OID 24665)
-- Name: users fk_users_roles; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_roles FOREIGN KEY (fk_role_id) REFERENCES public.roles(pk_role_id) ON DELETE RESTRICT;


-- Completed on 2026-02-22 15:11:41

--
-- PostgreSQL database dump complete
--
