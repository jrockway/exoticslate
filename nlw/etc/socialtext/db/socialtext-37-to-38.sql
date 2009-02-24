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
    ON signal (signal_id);

UPDATE "System"
    SET value = '38'
    WHERE field = 'socialtext-schema-version';

COMMIT;
