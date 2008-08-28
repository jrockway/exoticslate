BEGIN;

-- Remove the person fields that contain URIs to photos, now that
-- the photos are stored in DB

ALTER TABLE person
    DROP COLUMN photo;
ALTER TABLE person
    DROP COLUMN small_photo;

-- Remove the execute_(unless|if)_table_exists - these shouldn't be left
-- in the core schema.  Make sure they exist before we delete them.

CREATE OR REPLACE FUNCTION execute_if_table_exists (table_name TEXT, sql TEXT) RETURNS BOOLEAN AS $$
BEGIN
    RETURN(FALSE);
END
$$ LANGUAGE 'plpgsql' VOLATILE;

CREATE OR REPLACE FUNCTION execute_unless_table_exists (table_name TEXT, sql TEXT) RETURNS BOOLEAN AS $$
BEGIN
    RETURN(FALSE);
END
$$ LANGUAGE 'plpgsql' VOLATILE;

DROP FUNCTION execute_if_table_exists(text,text);
DROP FUNCTION execute_unless_table_exists(text,text);

UPDATE "System"
   SET value = 10
 WHERE field = 'socialtext-schema-version';

COMMIT;
