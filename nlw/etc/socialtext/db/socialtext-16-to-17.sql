BEGIN;

CREATE TABLE user_detail (
    user_id bigint NOT NULL PRIMARY KEY,
    username text NOT NULL,
    email_address text NOT NULL,
    "password" text NOT NULL,
    first_name text DEFAULT ''::text NOT NULL,
    last_name text DEFAULT ''::text NOT NULL,
    cached_at timestamptz
);

\x
\o /tmp/user_detail_migration.txt
SELECT * FROM "User";
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
    first_name::text,
    last_name::text,
    NULL::timestamptz
FROM "UserId" uid 
JOIN "User" u ON (uid.driver_unique_id = u.user_id)
WHERE uid.driver_key = 'Default';

-- recreate former "User" table indexes
CREATE UNIQUE INDEX "user_detail_lower_email_address"
	    ON user_detail (lower((email_address)::text));

CREATE UNIQUE INDEX "user_detail_lower_username"
	    ON user_detail (lower((username)::text));

DROP TABLE "User" CASCADE;

-- make the driver_unique_id the system_unique_id for Default users
UPDATE "UserId"
   SET driver_unique_id = system_unique_id
 WHERE driver_key = 'Default';

UPDATE "System"
   SET value = 17
 WHERE field = 'socialtext-schema-version';

COMMIT;
