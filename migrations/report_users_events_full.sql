-- EventPoint: Full relational report – users, events, admins, guests, images, prayers
-- Run against Neon/PostgreSQL. Shows all links and totals.
-- Usage: psql "<connection_string>" -f report_users_events_full.sql

\echo '============================================'
\echo '1. USERS (all)'
\echo '============================================'
SELECT
    u.pk_user_id     AS user_id,
    u.name,
    u.email,
    r.role_name      AS role,
    u.created_at
FROM users u
LEFT JOIN roles r ON r.pk_role_id = u.fk_role_id
ORDER BY u.created_at DESC;

\echo ''
\echo '============================================'
\echo '2. EVENTS with creator, category, privacy'
\echo '============================================'
SELECT
    e.pk_event_id       AS event_id,
    e.event_title,
    e.venue,
    e.event_date_time,
    creator.name        AS creator_name,
    creator.email       AS creator_email,
    ec.event_category_name,
    COALESCE(sc.sub_category_name, '-') AS sub_category,
    ep.privacy_name,
    e.created_at
FROM events e
LEFT JOIN users creator ON creator.pk_user_id = e.fk_creator_id
LEFT JOIN event_categories ec ON ec.pk_event_category_id = e.fk_event_category_id
LEFT JOIN sub_categories sc ON sc.pk_sub_category_id = e.fk_sub_category_id
LEFT JOIN event_privacy ep ON ep.pk_event_privacy_id = e.fk_event_privacy_id
ORDER BY e.created_at DESC;

\echo ''
\echo '============================================'
\echo '3. EVENT ADMINS (event + admin user + is_creator)'
\echo '============================================'
SELECT
    ea.pk_event_admin_id,
    ea.admin_code,
    ea.is_creator,
    e.event_title,
    u.name AS admin_name,
    u.email AS admin_email
FROM event_admins ea
JOIN events e ON e.pk_event_id = ea.fk_event_id
JOIN users u ON u.pk_user_id = ea.fk_user_id
ORDER BY e.event_title, ea.is_creator DESC, u.name;

\echo ''
\echo '============================================'
\echo '4. EVENT GUESTS (event + guest user + status + relationship)'
\echo '============================================'
SELECT
    eg.pk_event_guest_id,
    e.event_title,
    guest.name       AS guest_name,
    guest.email      AS guest_email,
    rs.status_name   AS request_status,
    rt.relationship_type_name,
    COALESCE(r.relationship_name, '-') AS relationship,
    inviter.name     AS invited_by,
    eg.images_uploaded_number,
    eg.updated_at    AS joined_at
FROM event_guests eg
JOIN events e ON e.pk_event_id = eg.fk_event_id
JOIN users guest ON guest.pk_user_id = eg.fk_user_id
LEFT JOIN request_statuses rs ON rs.pk_request_status_id = eg.fk_request_status_id
LEFT JOIN relationship_types rt ON rt.pk_relationship_type_id = eg.fk_relationship_type_id
LEFT JOIN relationships r ON r.pk_relationship_id = eg.fk_relationship_id
LEFT JOIN users inviter ON inviter.pk_user_id = eg.fk_relation_to_user_id
ORDER BY e.event_title, rs.pk_request_status_id, guest.name;

\echo ''
\echo '============================================'
\echo '5. EVENT IMAGES (event + uploader + approval)'
\echo '============================================'
SELECT
    ei.pk_event_image_id,
    e.event_title,
    ei.image_url,
    u.name   AS uploader_name,
    ei.is_approved,
    ei.likes_count,
    ei.created_at
FROM event_images ei
JOIN events e ON e.pk_event_id = ei.fk_event_id
JOIN users u ON u.pk_user_id = ei.fk_user_id
ORDER BY e.event_title, ei.created_at DESC;

\echo ''
\echo '============================================'
\echo '6. EVENT PRAYERS (event + user + message)'
\echo '============================================'
SELECT
    ep.pk_event_prayer_id,
    e.event_title,
    u.name   AS user_name,
    LEFT(ep.prayer_message, 60) || CASE WHEN LENGTH(ep.prayer_message) > 60 THEN '...' ELSE '' END AS prayer_preview,
    ep.created_at
FROM event_prayers ep
JOIN events e ON e.pk_event_id = ep.fk_event_id
JOIN users u ON u.pk_user_id = ep.fk_user_id
ORDER BY e.event_title, ep.created_at DESC;

\echo ''
\echo '============================================'
\echo '7. MASTER VIEW: User–Event linkage (admins + approved guests)'
\echo '============================================'
SELECT
    u.pk_user_id,
    u.name,
    u.email,
    e.pk_event_id      AS event_id,
    e.event_title,
    CASE
        WHEN ea.is_creator THEN 'Creator'
        WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin'
        WHEN eg.fk_request_status_id = 2 THEN 'Guest'
        ELSE 'Pending'
    END                AS participation_role,
    ea.admin_code
FROM users u
LEFT JOIN event_admins ea ON ea.fk_user_id = u.pk_user_id
LEFT JOIN event_guests eg ON eg.fk_user_id = u.pk_user_id
LEFT JOIN events e ON (
    (ea.fk_event_id IS NOT NULL AND e.pk_event_id = ea.fk_event_id)
    OR
    (eg.fk_event_id IS NOT NULL AND e.pk_event_id = eg.fk_event_id)
)
WHERE e.pk_event_id IS NOT NULL
  AND (ea.pk_event_admin_id IS NOT NULL OR eg.fk_request_status_id = 2)
ORDER BY u.name, e.event_title;

\echo ''
\echo '============================================'
\echo '8. TOTALS'
\echo '============================================'
SELECT
    (SELECT COUNT(*) FROM users)              AS total_users,
    (SELECT COUNT(*) FROM events)              AS total_events,
    (SELECT COUNT(*) FROM event_admins)        AS total_admin_memberships,
    (SELECT COUNT(*) FROM event_guests)       AS total_guest_records,
    (SELECT COUNT(*) FROM event_guests WHERE fk_request_status_id = 2) AS approved_guests,
    (SELECT COUNT(*) FROM event_guests WHERE fk_request_status_id = 1) AS pending_guests,
    (SELECT COUNT(*) FROM event_images)       AS total_images,
    (SELECT COUNT(*) FROM event_images WHERE is_approved) AS approved_images,
    (SELECT COUNT(*) FROM event_prayers)       AS total_prayers;

\echo ''
\echo '============================================'
\echo '9. PER-EVENT SUMMARY (creator, admins, guests, images, prayers)'
\echo '============================================'
SELECT
    e.pk_event_id,
    e.event_title,
    creator.name                AS creator_name,
    (SELECT COUNT(*) FROM event_admins ea2 WHERE ea2.fk_event_id = e.pk_event_id)
                                AS admin_count,
    (SELECT COUNT(*) FROM event_guests eg2 WHERE eg2.fk_event_id = e.pk_event_id AND eg2.fk_request_status_id = 2)
                                AS approved_guest_count,
    (SELECT COUNT(*) FROM event_guests eg2 WHERE eg2.fk_event_id = e.pk_event_id AND eg2.fk_request_status_id = 1)
                                AS pending_guest_count,
    (SELECT COUNT(*) FROM event_images ei2 WHERE ei2.fk_event_id = e.pk_event_id)
                                AS image_count,
    (SELECT COUNT(*) FROM event_prayers ep2 WHERE ep2.fk_event_id = e.pk_event_id)
                                AS prayer_count
FROM events e
LEFT JOIN users creator ON creator.pk_user_id = e.fk_creator_id
ORDER BY e.created_at DESC;

\echo ''
\echo '============================================'
\echo '10. PER-USER SUMMARY (events as creator/admin/guest)'
\echo '============================================'
SELECT
    u.pk_user_id,
    u.name,
    u.email,
    (SELECT COUNT(*) FROM events e WHERE e.fk_creator_id = u.pk_user_id)
        AS events_created,
    (SELECT COUNT(*) FROM event_admins ea WHERE ea.fk_user_id = u.pk_user_id AND ea.is_creator = FALSE)
        AS events_as_admin,
    (SELECT COUNT(*) FROM event_guests eg WHERE eg.fk_user_id = u.pk_user_id AND eg.fk_request_status_id = 2)
        AS events_as_guest,
    (SELECT COUNT(*) FROM event_images ei WHERE ei.fk_user_id = u.pk_user_id)
        AS images_uploaded
FROM users u
ORDER BY u.name;
