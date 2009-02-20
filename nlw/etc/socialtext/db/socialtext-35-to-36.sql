BEGIN;

<<<<<<< HEAD:nlw/etc/socialtext/db/socialtext-34-to-35.sql
CREATE TABLE gallery (
    account_id bigint NOT NULL,
    last_update timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT gallery_pk
            PRIMARY KEY (account_id),
    CONSTRAINT gallery_account_fk
            FOREIGN KEY (account_id)
            REFERENCES "Account"(account_id) ON DELETE CASCADE
);

CREATE TABLE gallery_gadget (
    gadget_id bigint NOT NULL,
    account_id bigint NOT NULL,
    position INTEGER NOT NULL,
    socialtext BOOLEAN NOT NULL,
    CONSTRAINT gallery_gadget_fk
            FOREIGN KEY (gadget_id)
            REFERENCES gadget(gadget_id) ON DELETE CASCADE,
    CONSTRAINT gallery_gadget_account_fk
            FOREIGN KEY (account_id)
            REFERENCES gallery(account_id) ON DELETE CASCADE
);
    
ALTER TABLE ONLY gadget
    ADD COLUMN description TEXT,
    ADD COLUMN uploaded BOOLEAN DEFAULT FALSE,
    ALTER COLUMN src DROP NOT NULL,
    ADD CONSTRAINT gadget_src_or_uploaded
            CHECK (src IS NOT NULL OR uploaded);

UPDATE "System"
    SET value = '35'
    WHERE field = 'socialtext-schema-version';
=======
ALTER TABLE container_type
    ADD COLUMN last_update timestamptz DEFAULT now() NOT NULL;

-- Update schema version
UPDATE "System"
   SET value = '35'
 WHERE field = 'socialtext-schema-version';
>>>>>>> iteration-2009-02-13:nlw/etc/socialtext/db/socialtext-34-to-35.sql

COMMIT;
