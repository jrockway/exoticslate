BEGIN;

-- page_tag lookups by tag are usually lower()'d
CREATE INDEX page_tag__workspace_lower_tag_ix 
    ON page_tag (workspace_id, lower(tag));

-- Update schema version
UPDATE "System"
   SET value = '29'
 WHERE field = 'socialtext-schema-version';

COMMIT;
