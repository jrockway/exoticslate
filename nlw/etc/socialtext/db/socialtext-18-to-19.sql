BEGIN;

-- extended-mode output:
\x

CREATE TABLE noun (
    noun_id VARCHAR(50) NOT NULL,
    noun_type VARCHAR(15) NOT NULL,
    at timestamptz DEFAULT now(),
    user_id bigint NOT NULL,
    body text
);

ALTER TABLE ONLY noun
    ADD CONSTRAINT noun_pkey
            PRIMARY KEY (noun_id);

ALTER TABLE ONLY noun
    ADD CONSTRAINT noun_user_id_fk
            FOREIGN KEY (user_id)
            REFERENCES users(user_id) ON DELETE CASCADE;

CREATE UNIQUE INDEX noun__noun_id
	    ON noun (noun_id);

-- finish up

UPDATE "System"
   SET value = 19
 WHERE field = 'socialtext-schema-version';

COMMIT;
