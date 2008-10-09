BEGIN;

--
-- Move from "User" to user_detail
--

CREATE TABLE user_detail (
    user_id bigint NOT NULL PRIMARY KEY,
    username text NOT NULL,
    email_address text NOT NULL,
    "password" text NOT NULL,
    first_name text DEFAULT ''::text NOT NULL,
    last_name text DEFAULT ''::text NOT NULL,
    cached_at timestamptz
);

-- make an emergency copy of the User and UserId tables

\x
\o /tmp/user_detail_migration.txt
SELECT * FROM "User";
\o
\x

\x
\o /tmp/user_detail_migration2.txt
SELECT * FROM "UserId";
\o
\x

-- migrate 'Default' users into the user_detail table
INSERT INTO user_detail 
(user_id, username, email_address, password,
 first_name, last_name, cached_at)
SELECT uid.system_unique_id::bigint,
    u.username::text,
    u.email_address::text,
    u.password::text,
    u.first_name::text,
    u.last_name::text,
    '+infinity'::timestamptz
FROM "UserId" uid 
JOIN "User" u ON (uid.driver_unique_id = u.user_id)
WHERE uid.driver_key = 'Default';

-- recreate former "User" table indexes
CREATE UNIQUE INDEX "user_detail_lower_email_address"
	    ON user_detail (lower((email_address)::text));

CREATE UNIQUE INDEX "user_detail_lower_username"
	    ON user_detail (lower((username)::text));

DROP TABLE "User" CASCADE;

-- make the driver_unique_id the user_id for Default users
UPDATE "UserId"
   SET driver_unique_id = system_unique_id
 WHERE driver_key = 'Default';

-- rename the user_id sequence (yes, it says TABLE but docs say to use this)
ALTER TABLE "UserId___system_unique_id" 
    RENAME TO "UserId___user_id";

DROP SEQUENCE "User___user_id";


--
-- Rename the system_unique_id column to user_id
--

ALTER TABLE "UserId" 
    RENAME COLUMN system_unique_id TO user_id;

-- functions don't get auto-updated
DROP FUNCTION auto_vivify_person();
CREATE FUNCTION auto_vivify_person() RETURNS "trigger"
    AS $$
BEGIN
    INSERT INTO person (id, last_update) 
        VALUES (NEW.user_id, '-infinity'::timestamptz);
    RETURN NEW;
END
$$
LANGUAGE plpgsql;

-- rename this ugly constraint (an fk constraint b/w Watchlist and UserId)
UPDATE pg_constraint 
   SET conname = 'watchlist_user_fk' 
 WHERE conname = 'watchlist___userid___user_id___system_unique_id___n___1___1___0';

-- rename the system_unique_id field coming out of this view
DROP VIEW user_account;
CREATE VIEW user_account AS
    SELECT DISTINCT 
        u.user_id, 
        u.driver_key, 
        u.driver_unique_id, 
        u.driver_username, 
        um.created_by_user_id AS creator_id, 
        um.creation_datetime, 
        um.primary_account_id, 
        w.account_id AS secondary_account_id
    FROM "UserId" u
    JOIN "UserMetadata" um USING (user_id)
    LEFT JOIN "UserWorkspaceRole" uwr USING (user_id)
    LEFT JOIN "Workspace" w USING (workspace_id);

UPDATE "System"
   SET value = 17
 WHERE field = 'socialtext-schema-version';

COMMIT;
