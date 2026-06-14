-- Row-Level Security policies + auth bridge for Supabase.
-- Apply AFTER schema.sql in the Supabase SQL editor.

-- =========================================================================
-- 1. Bridge auth.users (Supabase Auth) → public.users (our profile table)
-- =========================================================================

ALTER TABLE public.users
    ADD CONSTRAINT users_id_fk_auth
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email)
    VALUES (NEW.id, NEW.email)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- =========================================================================
-- 2. Enable RLS on every user-data table
-- =========================================================================

ALTER TABLE users                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE notebooks             ENABLE ROW LEVEL SECURITY;
ALTER TABLE templates             ENABLE ROW LEVEL SECURITY;
ALTER TABLE template_sections     ENABLE ROW LEVEL SECURITY;
ALTER TABLE prompts               ENABLE ROW LEVEL SECURITY;
ALTER TABLE entries               ENABLE ROW LEVEL SECURITY;
ALTER TABLE entry_section_values  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE entry_tags            ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_progress         ENABLE ROW LEVEL SECURITY;
ALTER TABLE habits                ENABLE ROW LEVEL SECURITY;
ALTER TABLE habit_goals           ENABLE ROW LEVEL SECURITY;
ALTER TABLE habit_logs            ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- 3. Policies — owner-only access on tables with a direct user_id column
-- =========================================================================

-- users: user can read/update their own profile row
CREATE POLICY "own profile read"   ON users FOR SELECT USING (id = auth.uid());
CREATE POLICY "own profile update" ON users FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- pattern: USING + WITH CHECK both pin to auth.uid()
CREATE POLICY "owner all" ON notebooks        FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON templates        FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON entries          FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON tags             FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON goals            FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON goal_progress    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON habits           FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "owner all" ON habit_logs       FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- =========================================================================
-- 4. Policies — child tables (access via parent's user_id)
-- =========================================================================

CREATE POLICY "owner via template" ON template_sections FOR ALL
    USING      (EXISTS (SELECT 1 FROM templates t WHERE t.id = template_id AND t.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM templates t WHERE t.id = template_id AND t.user_id = auth.uid()));

CREATE POLICY "owner via entry" ON entry_section_values FOR ALL
    USING      (EXISTS (SELECT 1 FROM entries e WHERE e.id = entry_id AND e.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM entries e WHERE e.id = entry_id AND e.user_id = auth.uid()));

CREATE POLICY "owner via entry" ON entry_tags FOR ALL
    USING      (EXISTS (SELECT 1 FROM entries e WHERE e.id = entry_id AND e.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM entries e WHERE e.id = entry_id AND e.user_id = auth.uid()));

CREATE POLICY "owner via entry" ON attachments FOR ALL
    USING      (EXISTS (SELECT 1 FROM entries e WHERE e.id = entry_id AND e.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM entries e WHERE e.id = entry_id AND e.user_id = auth.uid()));

CREATE POLICY "owner via habit" ON habit_goals FOR ALL
    USING      (EXISTS (SELECT 1 FROM habits h WHERE h.id = habit_id AND h.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM habits h WHERE h.id = habit_id AND h.user_id = auth.uid()));

-- =========================================================================
-- 5. Prompts — global read-only library for any signed-in user
-- =========================================================================

CREATE POLICY "any signed-in user can read" ON prompts
    FOR SELECT USING (auth.role() = 'authenticated' AND is_active);
-- No INSERT/UPDATE/DELETE policies on prompts — only seeded via service role / migrations.
