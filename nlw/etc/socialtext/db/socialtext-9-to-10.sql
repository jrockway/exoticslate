BEGIN;

-- Remove the person fields that contain URIs to photos, now that
-- the photos are stored in DB

ALTER TABLE person
    DROP COLUMN photo;
ALTER TABLE person
    DROP COLUMN small_photo;

UPDATE "System"
   SET value = 10
 WHERE field = 'socialtext-schema-version';

COMMIT;
