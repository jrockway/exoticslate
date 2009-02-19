BEGIN;

CREATE TABLE gallery (
    account_id bigint NOT NULL,
    last_update timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE gallery_gadget (
    gadget_id bigint NOT NULL,
    account_id bigint NOT NULL,
    position INTEGER NOT NULL,
    socialtext BOOLEAN NOT NULL
);
    
ALTER TABLE ONLY gallery
    ADD CONSTRAINT gallery_pk
            PRIMARY KEY (account_id),
    ADD CONSTRAINT gallery_account_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY gallery_gadget
    ADD CONSTRAINT gallery_gadget_fk
            FOREIGN KEY (gadget_id)
            REFERENCES gadget(gadget_id) ON DELETE CASCADE,
    ADD CONSTRAINT gallery_gadget_account_fk
            FOREIGN KEY (account_id)
            REFERENCES gallery(account_id) ON DELETE CASCADE;

ALTER TABLE ONLY gadget
    ADD COLUMN description TEXT;

UPDATE "System"
    SET value = '35'
    WHERE field = 'socialtext-schema-version';

COMMIT;
