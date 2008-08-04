BEGIN;

DROP TABLE event;

CREATE TABLE event (
    id bigint NOT NULL DEFAULT nextval('event_id_seq'),
    at timestamptz NOT NULL,
    action text NOT NULL,
    actor_id integer,
    event_class text NOT NULL,
    context text,
    page_id text,
    page_workspace_id bigint,
    person_id integer,
    tag_name text
);
 
CREATE INDEX ix_event_at
	    ON event (at);

CREATE INDEX ix_event_event_class_at
	    ON event (event_class, at);

CREATE INDEX ix_event_event_class_action_at
	    ON event (event_class, action, at);

CREATE INDEX ix_event_person_time
	    ON event (person_id, at)
            WHERE (event_class = 'person');

CREATE INDEX ix_event_actor_time
	    ON event (actor_id, at);

CREATE INDEX ix_event_for_page
	    ON event (page_workspace_id, page_id, at)
            WHERE (event_class = 'page');

CREATE INDEX ix_event_tag
	    ON event (tag_name, at)
            WHERE (event_class = 'page' OR event_class = 'person');

UPDATE "System"
    SET value = 7
    WHERE field = 'socialtext-schema-version';

COMMIT;
