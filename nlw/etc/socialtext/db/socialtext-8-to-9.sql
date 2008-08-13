BEGIN;

-- Remove the middle_name field from the person table

ALTER TABLE person
    DROP COLUMN middle_name;

UPDATE "System"
   SET value = 9
 WHERE field = 'socialtext-schema-version';

COMMIT;
