BEGIN;

CREATE TABLE signal_account (
    signal_id bigint NOT NULL,
    account_id bigint NOT NULL
);

ALTER TABLE ONLY signal_account
    ADD CONSTRAINT signal_account_fk
        FOREIGN KEY (signal_id)
        REFERENCES signal (signal_id) ON DELETE CASCADE;

ALTER TABLE ONLY signal_account
    ADD CONSTRAINT signal_account_signal_fk
        FOREIGN KEY (account_id)
        REFERENCES "Account" (account_id) ON DELETE CASCADE;

CREATE INDEX ix_signal_account
    ON signal_account (signal_id);

CREATE UNIQUE INDEX ix_signal_account_account
    ON signal_account (account_id, signal_id);

-- populate signal_account table with people's accounts
SET enable_seqscan TO off; -- don't use SeqScans if possible

INSERT INTO signal_account (signal_id, account_id)
    SELECT DISTINCT ON (signal.signal_id, au.account_id) signal.signal_id, au.account_id
    FROM signal
        LEFT JOIN signal_account sa USING (signal_id)
        LEFT JOIN account_user au USING (user_id)
    WHERE sa.account_id IS NULL; -- anti-join

SET enable_seqscan TO DEFAULT;

UPDATE "System"
    SET value = '39'
    WHERE field = 'socialtext-schema-version';

COMMIT;
