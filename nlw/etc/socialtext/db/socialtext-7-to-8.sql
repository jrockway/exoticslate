BEGIN;

-- Nice and simple, let's just add a couple of additional fields. Once they
-- are populated, we'll delete the old fields and move these over.

ALTER TABLE person
    ADD COLUMN photo_image bytea;

ALTER TABLE person
    ADD COLUMN small_photo_image bytea;

UPDATE "System"
   SET value = 8
 WHERE field = 'socialtext-schema-version';

COMMIT;
