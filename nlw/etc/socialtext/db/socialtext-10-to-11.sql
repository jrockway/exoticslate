BEGIN;

-- Add a primary_account_id column to UserMetadata which is permitted
-- to be NULL now, but will be NOT NULL in the future.

ALTER TABLE person
    ADD COLUMN
        last_update timestamptz DEFAULT now();


UPDATE "System"
   SET value = 11
 WHERE field = 'socialtext-schema-version';

COMMIT;
