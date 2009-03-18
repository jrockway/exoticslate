BEGIN;

ALTER TABLE gallery_gadget
    ADD COLUMN section TEXT,
    ADD COLUMN removed BOOLEAN DEFAULT FALSE;

UPDATE gallery_gadget
   SET section = 
    CASE WHEN socialtext THEN 'socialtext'
         WHEN gallery_id > 0 THEN 'account'
         ELSE 'thirdparty'
    END;

ALTER TABLE gallery_gadget
    ALTER COLUMN section SET NOT NULL,
     DROP COLUMN socialtext;

UPDATE "System"
   SET value = '44'
 WHERE field = 'socialtext-schema-version';

COMMIT;
