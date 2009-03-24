BEGIN;

-- reserved for Story: user can insert user mentions into signals
-- and Story: user can reply to signals and view replies

ALTER TABLE signal
    ADD COLUMN in_reply_to_id bigint;

ALTER TABLE signal
    ADD CONSTRAINT in_reply_to_fk
        FOREIGN KEY (in_reply_to_id)
        REFERENCES signal(signal_id) ON DELETE CASCADE;

CREATE INDEX ix_signal_reply ON signal (in_reply_to_id);

UPDATE "System"
   SET value = '45'
 WHERE field = 'socialtext-schema-version';

COMMIT;
