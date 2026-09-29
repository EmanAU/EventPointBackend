-- EventPoint data insert script (data only)
-- Run against Neon/PostgreSQL after schema exists

-- colors
INSERT INTO public.colors (pk_color_id, color_name, color_code) OVERRIDING SYSTEM VALUE VALUES
(1, 'Blue', '#007BFF'),
(2, 'Red', '#FF0000'),
(3, 'Green', '#28A745'),
(4, 'Purple', '#6F42C1'),
(5, 'Orange', '#FD7E14')
ON CONFLICT (pk_color_id) DO NOTHING;

-- roles (required for user_create)
INSERT INTO public.roles (pk_role_id, role_name) OVERRIDING SYSTEM VALUE VALUES
(1, 'User')
ON CONFLICT (pk_role_id) DO NOTHING;

-- event_categories
INSERT INTO public.event_categories (pk_event_category_id, event_category_name) OVERRIDING SYSTEM VALUE VALUES
(1, 'Marriage'),
(2, 'Birth'),
(3, 'Death'),
(4, 'Graduation'),
(5, 'Birthday'),
(6, 'Retirement'),
(7, 'Housewarming'),
(8, 'Conference'),
(9, 'Product Launch'),
(10, 'Anniversary'),
(11, 'Training'),
(12, 'Religious Festival'),
(13, 'Pilgrimage'),
(14, 'Cultural Festival'),
(15, 'Concert'),
(16, 'Sports'),
(17, 'Exhibition'),
(18, 'Reunion'),
(19, 'Vacation/Trip')
ON CONFLICT (pk_event_category_id) DO NOTHING;

-- event_privacy
INSERT INTO public.event_privacy (pk_event_privacy_id, privacy_name) OVERRIDING SYSTEM VALUE VALUES
(1, 'Public'),
(2, 'Guests Only')
ON CONFLICT (pk_event_privacy_id) DO NOTHING;

-- relationship_types
INSERT INTO public.relationship_types (pk_relationship_type_id, relationship_type_name) OVERRIDING SYSTEM VALUE VALUES
(1, 'Family'),
(2, 'Friend'),
(3, 'Professional')
ON CONFLICT (pk_relationship_type_id) DO NOTHING;

-- relationships
INSERT INTO public.relationships (pk_relationship_id, fk_relationship_type_id, relationship_name) OVERRIDING SYSTEM VALUE VALUES
(1, 1, 'Father'),
(2, 1, 'Mother'),
(3, 1, 'Sister'),
(4, 1, 'Grand Father'),
(5, 1, 'Grand Mother'),
(6, 1, 'Mother in Law'),
(7, 1, 'Father in Law'),
(8, 1, 'Brother in Law'),
(9, 1, 'Sister in Law'),
(10, 1, 'Wife'),
(11, 1, 'Husband'),
(12, 1, 'Cousin'),
(13, 1, 'Uncle'),
(14, 1, 'Daughter'),
(15, 1, 'Son'),
(16, 1, 'Grand Son'),
(17, 1, 'Grand Daughter'),
(18, 1, 'Spouse'),
(19, 1, 'Fiancé'),
(20, 1, 'Aunt'),
(21, 1, 'Nephew'),
(22, 1, 'Niece'),
(23, 1, 'Son in Law'),
(24, 1, 'Daughter in Law'),
(25, 1, 'Stepfather'),
(26, 1, 'Stepmother'),
(27, 1, 'Stepbrother'),
(28, 1, 'Stepsister'),
(29, 1, 'Stepson'),
(30, 1, 'Stepdaughter'),
(31, 1, 'Half-brother'),
(32, 1, 'Half-Sister'),
(33, 1, 'Fiancée'),
(34, 1, 'Great-Uncle'),
(35, 1, 'Great-Aunt'),
(36, 2, 'Best Friend'),
(37, 2, 'Close Friend'),
(38, 2, 'Friend'),
(39, 2, 'Acquaintance'),
(40, 2, 'Childhood Friend'),
(41, 2, 'Family Friend'),
(42, 2, 'Confidant'),
(43, 2, 'Classmate'),
(44, 2, 'Batchmate'),
(45, 2, 'Schoolmate'),
(46, 2, 'Peer'),
(47, 2, 'Roommate'),
(48, 2, 'Junior'),
(49, 2, 'Alumni'),
(50, 3, 'Colleague'),
(51, 3, 'Co-worker'),
(52, 3, 'Teammate'),
(53, 3, 'Associate'),
(54, 3, 'Boss'),
(55, 3, 'Business Partner'),
(56, 3, 'Client'),
(57, 3, 'Customer'),
(58, 3, 'Professor'),
(59, 3, 'Teacher'),
(60, 3, 'Lab Instructor'),
(61, 3, 'Mentor'),
(62, 3, 'Supervisor')
ON CONFLICT (pk_relationship_id) DO NOTHING;

-- request_statuses
INSERT INTO public.request_statuses (pk_request_status_id, status_name) OVERRIDING SYSTEM VALUE VALUES
(1, 'Pending'),
(2, 'Accepted'),
(3, 'Declined')
ON CONFLICT (pk_request_status_id) DO NOTHING;

-- sub_categories
INSERT INTO public.sub_categories (pk_sub_category_id, fk_event_category_id, sub_category_name) OVERRIDING SYSTEM VALUE VALUES
(1, 1, 'Proposal'),
(2, 1, 'Engagement'),
(3, 1, 'Bridal Shower'),
(4, 1, 'Bachelor Party'),
(5, 1, 'Bachelorette Party'),
(6, 1, 'Rehearsal Dinner'),
(7, 1, 'Dholki'),
(8, 1, 'Mayun'),
(9, 1, 'Haldi'),
(10, 1, 'Mehndi'),
(11, 1, 'Qawwali Night'),
(12, 1, 'Nikah'),
(13, 1, 'Wedding Ceremony'),
(14, 1, 'Sehra Bandi'),
(15, 1, 'Dua Khair'),
(16, 1, 'Barat/Rukhsati'),
(17, 1, 'Reception'),
(18, 1, 'Walima'),
(19, 1, 'Chauthi'),
(20, 1, 'Honeymoon'),
(21, 1, 'Anniversary')
ON CONFLICT (pk_sub_category_id) DO NOTHING;

-- users
INSERT INTO public.users (pk_user_id, name, email, phone_number, fk_role_id, created_at, updated_at, profile_image_url) VALUES
('JienU7rv', 'Asim Ali Fayyaz', 'yesiamrana@gmail.com', '03154489895', 1, '2026-02-07 15:06:24.536571+05', '2026-02-07 15:06:24.536571+05', NULL),
('YIFaw8ES', 'Saad Hassan', 'saadhassaniq1.7@gmail.com', '03123444785', 1, '2026-02-07 15:06:24.536571+05', '2026-02-07 15:06:24.536571+05', NULL),
('eVN1aCgG', 'Sudair Khan', 'sudairkhan@gmail.com', '03154489895', 1, '2026-02-07 15:06:24.536571+05', '2026-02-07 15:06:24.536571+05', NULL),
('Vcf0fF5v', 'eman ali', 'emanalishmsi7thyellow@gmail.com', '', 1, '2026-02-10 00:07:35.915385+05', '2026-02-10 00:07:35.915385+05', NULL),
('5y1izEZh', 'Eman Ali', '241089@students.au.edu.pk', '03150425110', 1, '2026-02-07 14:33:37.994624+05', '2026-02-20 02:04:15.604384+05', 'https://business.careho.pk/about/emanali')
ON CONFLICT (pk_user_id) DO NOTHING;

-- events
INSERT INTO public.events (pk_event_id, fk_event_category_id, fk_sub_category_id, event_title, tag_line, expected_guest_number, venue, event_date_time, fk_creator_id, created_at, event_cover_image_url, fk_event_privacy_id) VALUES
('Ye9C0l3c', 1, 1, 'Wedding', 'Eman''s Wedding', 690, 'Venue', '2026-02-18 00:54:17.94+05', '5y1izEZh', '2026-02-18 00:56:12.953+05', 'www.imageurl.com/url', 1)
ON CONFLICT (pk_event_id) DO NOTHING;

-- event_admins
INSERT INTO public.event_admins (pk_event_admin_id, fk_user_id, fk_event_id, admin_code, is_creator, fk_color_id, created_at) VALUES
('lUZ0G1iX', '5y1izEZh', 'Ye9C0l3c', 'CVJkCX', true, 1, '2026-02-18 00:56:12.953+05')
ON CONFLICT (pk_event_admin_id) DO NOTHING;

-- event_guests
INSERT INTO public.event_guests (pk_event_guest_id, fk_user_id, fk_event_id, fk_relationship_type_id, fk_relationship_id, fk_relation_to_user_id, fk_request_status_id, images_uploaded_number, created_at, updated_at) VALUES
('XDVTbCdC', 'JienU7rv', 'Ye9C0l3c', 1, 1, '5y1izEZh', 2, 0, '2026-02-18 00:56:33.511798+05', '2026-02-18 00:57:01.268335+05')
ON CONFLICT (pk_event_guest_id) DO NOTHING;

-- event_images
INSERT INTO public.event_images (pk_event_image_id, fk_user_id, fk_guest_id, fk_event_id, image_url, is_approved, created_at, likes_count) VALUES
('NNPDt1T4', '5y1izEZh', NULL, 'Ye9C0l3c', 'https://rb.gy/kzo5i2', true, '2026-02-20 01:28:35.171709+05', 0)
ON CONFLICT (pk_event_image_id) DO NOTHING;

-- Reset sequences so new inserts get correct IDs
SELECT pg_catalog.setval('public.colors_pk_color_id_seq', 5, true);
SELECT pg_catalog.setval('public.event_categories_pk_event_category_id_seq', 19, true);
SELECT pg_catalog.setval('public.event_privacy_pk_event_privacy_id_seq', 2, true);
SELECT pg_catalog.setval('public.image_likes_pk_image_like_id_seq', 1, false);
SELECT pg_catalog.setval('public.image_privacy_pk_image_privacy_id_seq', 1, false);
SELECT pg_catalog.setval('public.relationship_types_pk_relationship_type_id_seq', 3, true);
SELECT pg_catalog.setval('public.relationships_pk_relationship_id_seq', 62, true);
SELECT pg_catalog.setval('public.request_statuses_pk_request_status_id_seq', 3, true);
SELECT pg_catalog.setval('public.roles_pk_role_id_seq', 1, true);
SELECT pg_catalog.setval('public.sub_categories_pk_sub_category_id_seq', 21, true);
