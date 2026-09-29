-- Add subcategories for all event categories
-- Conference already has General from initial migration

INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Traditional' FROM event_categories ec WHERE ec.event_category_name = 'Wedding'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Traditional');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Beach' FROM event_categories ec WHERE ec.event_category_name = 'Wedding'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Beach');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Garden' FROM event_categories ec WHERE ec.event_category_name = 'Wedding'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Garden');

INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Kids' FROM event_categories ec WHERE ec.event_category_name = 'Birthday'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Kids');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Adult' FROM event_categories ec WHERE ec.event_category_name = 'Birthday'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Adult');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Surprise' FROM event_categories ec WHERE ec.event_category_name = 'Birthday'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Surprise');

INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Meeting' FROM event_categories ec WHERE ec.event_category_name = 'Corporate'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Meeting');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Team Building' FROM event_categories ec WHERE ec.event_category_name = 'Corporate'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Team Building');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Product Launch' FROM event_categories ec WHERE ec.event_category_name = 'Corporate'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Product Launch');

INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Party' FROM event_categories ec WHERE ec.event_category_name = 'Social'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Party');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Meetup' FROM event_categories ec WHERE ec.event_category_name = 'Social'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Meetup');
INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'Reunion' FROM event_categories ec WHERE ec.event_category_name = 'Social'
AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id AND sub_category_name = 'Reunion');
