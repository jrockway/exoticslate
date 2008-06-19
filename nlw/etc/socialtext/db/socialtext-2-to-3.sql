BEGIN;

IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = "storage")
    DROP TABLE storage;

CREATE TABLE "storage" (
    user_id bigint NOT NULL,
    "class" varchar(128),
    "key" varchar(128),
    value text,
    datatype varchar(10)
);

COMMIT;
