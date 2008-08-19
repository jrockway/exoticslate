BEGIN;

-- update the User table with profile-selected names

UPDATE "User"
SET first_name = person.first_name
FROM person
WHERE "User".first_name ~ '^\\s*'
  AND "User".user_id = person.id
  AND person.first_name IS NOT NULL;

UPDATE "User"
SET last_name = person.last_name
FROM person
WHERE "User".last_name ~ '^\\s*'
  AND "User".user_id = person.id
  AND person.last_name IS NOT NULL;

-- Remove the name, first_name, middle_name, last_name and email fields from the person table

ALTER TABLE person
    DROP COLUMN name;

ALTER TABLE person
    DROP COLUMN first_name;

ALTER TABLE person
    DROP COLUMN middle_name;

ALTER TABLE person
    DROP COLUMN last_name;

ALTER TABLE person
    DROP COLUMN email;

UPDATE "System"
   SET value = 9
 WHERE field = 'socialtext-schema-version';

COMMIT;
