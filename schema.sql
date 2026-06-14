-- MyJournal schema
-- Postgres, cloud-first, single-user-per-account.
-- Structured daily-review journaling with templates, habits, and goals.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================================================================
-- users
-- =========================================================================
CREATE TABLE users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email           text NOT NULL UNIQUE,
    display_name    text,
    timezone        text NOT NULL DEFAULT 'UTC',
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- =========================================================================
-- notebooks  (a user can keep multiple journals: Work, Personal, Dreams, ...)
-- =========================================================================
CREATE TABLE notebooks (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            text NOT NULL,
    color           text,
    icon            text,
    sort_order      int  NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz
);
CREATE INDEX idx_notebooks_user ON notebooks(user_id) WHERE deleted_at IS NULL;

-- =========================================================================
-- templates  (structured entry definitions: Morning Review, Weekly Review...)
-- =========================================================================
CREATE TABLE templates (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            text NOT NULL,
    description     text,
    schedule_kind   text NOT NULL CHECK (schedule_kind IN ('daily','weekly','monthly','on_demand')),
    is_default      boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz
);
-- one default template per (user, schedule_kind)
CREATE UNIQUE INDEX idx_templates_default
    ON templates(user_id, schedule_kind)
    WHERE is_default AND deleted_at IS NULL;

-- =========================================================================
-- template_sections  (the typed fields inside a template)
-- =========================================================================
CREATE TABLE template_sections (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id     uuid NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    position        int  NOT NULL,
    label           text NOT NULL,
    kind            text NOT NULL CHECK (kind IN (
                        'short_text','long_text','list','rating','number',
                        'boolean','mood','tags','prompt','habits'
                    )),
    required        boolean NOT NULL DEFAULT false,
    -- kind-specific config:
    --   rating: {"min":1,"max":10}
    --   list:   {"min_items":3,"max_items":3,"placeholder":"a win"}
    --   prompt: {"category":"gratitude"}  or  {"prompt_id":"<uuid>"}
    --   habits: {"goal_id":"<uuid|null>"}  (filters which habits to surface)
    config          jsonb NOT NULL DEFAULT '{}'::jsonb,
    deleted_at      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_template_sections_template ON template_sections(template_id, position)
    WHERE deleted_at IS NULL;

-- =========================================================================
-- prompts  (global library of guided prompts a section can pull from)
-- =========================================================================
CREATE TABLE prompts (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    text            text NOT NULL,
    category        text,
    is_active       boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_prompts_category ON prompts(category) WHERE is_active;

-- =========================================================================
-- entries  (one filled-out template instance)
-- =========================================================================
CREATE TABLE entries (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notebook_id     uuid REFERENCES notebooks(id) ON DELETE SET NULL,
    template_id     uuid NOT NULL REFERENCES templates(id) ON DELETE RESTRICT,
    entry_date      date NOT NULL,
    entry_period    daterange,                -- for weekly/monthly templates
    mood_score      smallint CHECK (mood_score BETWEEN 1 AND 5),
    mood_label      text,
    location_name   text,
    location_lat    numeric(9,6),
    location_lng    numeric(9,6),
    completed_at    timestamptz,              -- null = draft; set when user finishes the review
    version         int  NOT NULL DEFAULT 1,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz
);
CREATE INDEX idx_entries_user_date     ON entries(user_id, entry_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_entries_template_date ON entries(user_id, template_id, entry_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_entries_notebook_date ON entries(user_id, notebook_id, entry_date DESC) WHERE deleted_at IS NULL;
-- Note: per-day uniqueness for daily templates is enforced in the app layer
-- (can't easily express "unique only when schedule_kind='daily'" without denormalizing).

-- =========================================================================
-- entry_section_values  (the answers; snapshot label/kind for history safety)
-- =========================================================================
CREATE TABLE entry_section_values (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id                 uuid NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    section_id               uuid NOT NULL REFERENCES template_sections(id) ON DELETE RESTRICT,
    section_label_snapshot   text NOT NULL,
    section_kind_snapshot    text NOT NULL,
    value_text               text,
    value_number             numeric,
    value_json               jsonb,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now(),
    UNIQUE (entry_id, section_id)
);
CREATE INDEX idx_section_values_entry ON entry_section_values(entry_id);

-- =========================================================================
-- tags + entry_tags
-- =========================================================================
CREATE TABLE tags (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            text NOT NULL,
    color           text,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX idx_tags_user_name ON tags(user_id, lower(name));

CREATE TABLE entry_tags (
    entry_id        uuid NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    tag_id          uuid NOT NULL REFERENCES tags(id)    ON DELETE CASCADE,
    PRIMARY KEY (entry_id, tag_id)
);

-- =========================================================================
-- attachments  (object-storage refs; do not store blobs in Postgres)
-- =========================================================================
CREATE TABLE attachments (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id        uuid NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
    kind            text NOT NULL CHECK (kind IN ('image','audio','video','file')),
    storage_key     text NOT NULL,
    mime_type       text,
    size_bytes      bigint,
    width           int,
    height          int,
    duration_ms     int,
    caption         text,
    sort_order      int  NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_attachments_entry ON attachments(entry_id);

-- =========================================================================
-- goals  (what the user is working toward)
-- =========================================================================
CREATE TABLE goals (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           text NOT NULL,
    description     text,
    status          text NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','paused','achieved','abandoned')),
    start_date      date NOT NULL DEFAULT CURRENT_DATE,
    target_date     date,
    -- optional measurable target (e.g. lose 5 kg, run 100 km, read 12 books)
    target_value    numeric,
    target_unit     text,        -- 'kg', 'km', 'books', 'minutes', etc.
    color           text,
    icon            text,
    achieved_at     timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    deleted_at      timestamptz
);
CREATE INDEX idx_goals_user_status ON goals(user_id, status) WHERE deleted_at IS NULL;

-- =========================================================================
-- goal_progress  (periodic check-ins for goals with a measurable metric)
-- =========================================================================
CREATE TABLE goal_progress (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_id         uuid NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    recorded_on     date NOT NULL DEFAULT CURRENT_DATE,
    value           numeric NOT NULL,
    note            text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (goal_id, recorded_on)
);
CREATE INDEX idx_goal_progress_goal ON goal_progress(goal_id, recorded_on DESC);

-- =========================================================================
-- habits  (recurring actions; optionally laddering up to a goal)
-- =========================================================================
CREATE TABLE habits (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                    text NOT NULL,
    description             text,
    -- 'boolean' = did/didn't; 'numeric' = quantity (e.g. 30 minutes, 50 pushups)
    kind                    text NOT NULL CHECK (kind IN ('boolean','numeric')),
    unit                    text,                 -- e.g. 'minutes','reps','pages' (numeric kind)
    target_per_occurrence   numeric,              -- e.g. 30 (minutes per session)
    frequency_kind          text NOT NULL CHECK (frequency_kind IN
                                ('daily','weekdays','weekends','x_per_week','x_per_month','custom')),
    frequency_target        int,                  -- e.g. 5 (for x_per_week)
    color                   text,
    icon                    text,
    start_date              date NOT NULL DEFAULT CURRENT_DATE,
    end_date                date,
    archived_at             timestamptz,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    deleted_at              timestamptz
);
CREATE INDEX idx_habits_user_active ON habits(user_id)
    WHERE archived_at IS NULL AND deleted_at IS NULL;

-- habits ↔ goals  (m2m: one habit can ladder to multiple goals)
CREATE TABLE habit_goals (
    habit_id        uuid NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    goal_id         uuid NOT NULL REFERENCES goals(id)  ON DELETE CASCADE,
    PRIMARY KEY (habit_id, goal_id)
);
CREATE INDEX idx_habit_goals_goal ON habit_goals(goal_id);

-- =========================================================================
-- habit_logs  (one row per habit per day; canonical record of completion)
-- =========================================================================
CREATE TABLE habit_logs (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    habit_id        uuid NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    log_date        date NOT NULL,
    completed       boolean NOT NULL DEFAULT false,
    value           numeric,           -- for numeric habits (e.g. 25 minutes)
    note            text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (habit_id, log_date)
);
CREATE INDEX idx_habit_logs_user_date ON habit_logs(user_id, log_date DESC);
CREATE INDEX idx_habit_logs_habit     ON habit_logs(habit_id, log_date DESC);

-- =========================================================================
-- updated_at trigger
-- =========================================================================
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users','notebooks','templates','entries','entry_section_values',
        'goals','habits','habit_logs'
    ]
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION set_updated_at();', t, t);
    END LOOP;
END $$;
