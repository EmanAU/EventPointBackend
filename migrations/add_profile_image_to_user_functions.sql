-- Migration: Add profile_image_url to user_get_by_id and user_get_by_email return types
-- The users table already has profile_image_url column
-- The user_update_profile function already exists and updates profile_image_url
-- This migration updates user_get_by_id and user_get_by_email to return ProfileImageUrl

-- ============================================
-- DROP existing functions (return type changed)
-- ============================================
DROP FUNCTION IF EXISTS user_get_by_id(character varying);
DROP FUNCTION IF EXISTS user_get_by_email(character varying);

-- ============================================
-- RECREATE user_get_by_id with ProfileImageUrl
-- ============================================
CREATE OR REPLACE FUNCTION user_get_by_id(_user_id character varying)
RETURNS TABLE (
    "UserId" character varying,
    "Name" character varying,
    "Email" character varying,
    "PhoneNumber" character varying,
    "ProfileImageUrl" text,
    "RoleName" character varying,
    "CreatedAt" date,
    "UpdatedAt" date
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.pk_user_id,
        u.name,
        u.email,
        u.phone_number,
        COALESCE(u.profile_image_url, '')::text,
        r.role_name,
        u.created_at::DATE,
        u.updated_at::DATE
    FROM users u
    INNER JOIN roles r ON u.fk_role_id = r.pk_role_id
    WHERE u.pk_user_id = _user_id;
END;
$$;

-- ============================================
-- RECREATE user_get_by_email with ProfileImageUrl
-- ============================================
CREATE OR REPLACE FUNCTION user_get_by_email(p_user_email character varying)
RETURNS TABLE (
    "UserId" character varying,
    "Name" character varying,
    "Email" character varying,
    "PhoneNumber" character varying,
    "ProfileImageUrl" text,
    "RoleName" character varying,
    "CreatedAt" date,
    "UpdatedAt" date
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.pk_user_id,
        u.name,
        u.email,
        u.phone_number,
        COALESCE(u.profile_image_url, '')::text,
        r.role_name,
        u.created_at::DATE,
        u.updated_at::DATE
    FROM users u
    INNER JOIN roles r ON u.fk_role_id = r.pk_role_id
    WHERE u.email = p_user_email;
END;
$$;
