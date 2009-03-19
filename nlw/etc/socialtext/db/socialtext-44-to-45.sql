BEGIN;

-- reserved for Story: user can insert user mentions into signals
-- and Story: user can reply to signals and view replies

UPDATE "System"
   SET value = '45'
 WHERE field = 'socialtext-schema-version';

COMMIT;
