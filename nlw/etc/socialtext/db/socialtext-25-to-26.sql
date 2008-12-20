BEGIN;

ALTER TABLE profile_field
    ADD COLUMN is_user_editable boolean DEFAULT true NOT NULL;

-- Update schema version
UPDATE "System"
   SET value = '26'
 WHERE field = 'socialtext-schema-version';

COMMIT;
