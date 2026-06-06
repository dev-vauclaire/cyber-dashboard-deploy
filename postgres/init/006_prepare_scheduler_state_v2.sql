/*
 * Migrations V2 - nouvelle table scheduler_state_v2.
 *
 * L'ancienne table scheduler_state est conservee pour permettre une migration progressive.
 */

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'scheduler_job_status'
    ) THEN
        CREATE TYPE scheduler_job_status AS ENUM (
            'never_run',
            'pending',
            'running',
            'success',
            'failed'
        );
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS scheduler_state_v2 (
    attacks_collector_config_id INT PRIMARY KEY
        REFERENCES attacks_collector_config(id) ON DELETE CASCADE,

    last_inventory_at TIMESTAMPTZ NULL,
    last_inventory_status scheduler_job_status NOT NULL DEFAULT 'never_run',
    last_inventory_error TEXT NULL,

    last_collection_at TIMESTAMPTZ NULL,
    last_collection_status scheduler_job_status NOT NULL DEFAULT 'never_run',
    last_collection_error TEXT NULL,

    inventory_requested_at TIMESTAMPTZ NULL,
    inventory_requested_by VARCHAR(150) NULL,

    collection_cursor JSONB NULL,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Migration finale à décommenté lors de la bascule finale
/*
DROP TABLE IF EXISTS scheduler_state;

ALTER TABLE scheduler_state_v2
RENAME TO scheduler_state;
*/
