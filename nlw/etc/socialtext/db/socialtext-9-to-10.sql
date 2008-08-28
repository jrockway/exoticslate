BEGIN;

CREATE TABLE

UPDATE "System"
   SET value = 10
 WHERE field = 'socialtext-schema-version';

COMMIT;
