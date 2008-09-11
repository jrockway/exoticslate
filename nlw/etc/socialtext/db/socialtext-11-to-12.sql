BEGIN;

-- Add a primary_account_id column to UserMetadata which is permitted
-- to be NULL now, but will be NOT NULL in the future.

ALTER TABLE person
    ADD COLUMN
        last_update timestamptz DEFAULT now();

-- Auto-vivify should set last_update to way in the past

DROP FUNCTION auto_vivify_person() CASCADE;
CREATE FUNCTION auto_vivify_person() RETURNS "trigger"
    AS $$
BEGIN
    INSERT INTO person (id, last_update) 
        VALUES (NEW.system_unique_id, '-Infinity'::timestamptz);
    RETURN NEW;
END
$$
    LANGUAGE plpgsql;

CREATE TRIGGER person_ins
    AFTER INSERT ON "UserId"
    FOR EACH ROW
    EXECUTE PROCEDURE auto_vivify_person();

-- Add a skin_name field to an Account
ALTER TABLE "Account" ADD COLUMN
    skin_name varchar(30) DEFAULT 's2'::varchar NOT NULL;

-- Change the default workspace skin so it inherits from Account
ALTER TABLE "Workspace" ALTER COLUMN skin_name SET DEFAULT ''::varchar;

UPDATE "System"
   SET value = 12
 WHERE field = 'socialtext-schema-version';

COMMIT;
