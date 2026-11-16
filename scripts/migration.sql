-- ====================================================================
-- OPENSOFTWARES CRM - 3 TABLES DATABASE SCHEMA & POLICIES
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Table 1: crm_profiles
CREATE TABLE IF NOT EXISTS public.crm_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    mobile_number TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin_founder', 'founder', 'channel_partner')),
    team TEXT NOT NULL DEFAULT 'Gulbarga' CHECK (team IN ('Gulbarga', 'Solapur', 'Both')),
    permissions JSONB NOT NULL DEFAULT '{
        "tabs": ["home", "pipeline", "products", "profile"],
        "modules": {
            "tasks": {"create": true, "edit": true, "delete": true},
            "products": {"create": true, "edit": true, "delete": true},
            "leads": {"create": true, "edit": true, "delete": true},
            "partners": {"create": true, "edit": true, "delete": true},
            "collections": {"create": true, "edit": true, "delete": true},
            "meetings": {"create": true, "edit": true, "delete": true},
            "notices": {"create": true, "edit": true, "delete": true}
        }
    }'::jsonb,
    is_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    first_login_change_required BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 2: crm_records (Polymorphic core entity table)
CREATE TABLE IF NOT EXISTS public.crm_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('product', 'lead', 'task', 'partner', 'partner_visit', 'followup', 'collection', 'meeting', 'notice', 'quick_alert', 'activity_log')),
    title TEXT NOT NULL,
    description TEXT,
    team TEXT DEFAULT 'Gulbarga' CHECK (team IN ('Gulbarga', 'Solapur', 'Both')),
    status TEXT DEFAULT 'new',
    priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    assigned_to UUID REFERENCES public.crm_profiles(id) ON DELETE SET NULL,
    partner_id UUID REFERENCES public.crm_records(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.crm_records(id) ON DELETE CASCADE,
    client_name TEXT,
    amount_due NUMERIC(12,2) DEFAULT 0,
    amount_received NUMERIC(12,2) DEFAULT 0,
    due_date TIMESTAMPTZ,
    meeting_time TIMESTAMPTZ,
    extra_data JSONB DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES public.crm_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 3: crm_notifications (Device tokens, push logs, reminders)
CREATE TABLE IF NOT EXISTS public.crm_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.crm_profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    platform TEXT DEFAULT 'android',
    notification_type TEXT DEFAULT 'general' CHECK (notification_type IN ('alerts', 'reminders', 'general', 'task', 'meeting', 'collection')),
    title TEXT,
    body TEXT,
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_user_device UNIQUE(user_id, device_token)
);

-- Indexes for lightning fast queries
CREATE INDEX IF NOT EXISTS idx_crm_records_type ON public.crm_records(entity_type);
CREATE INDEX IF NOT EXISTS idx_crm_records_team ON public.crm_records(team);
CREATE INDEX IF NOT EXISTS idx_crm_records_assigned ON public.crm_records(assigned_to);
CREATE INDEX IF NOT EXISTS idx_crm_records_product ON public.crm_records(product_id);
CREATE INDEX IF NOT EXISTS idx_crm_records_created_at ON public.crm_records(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_crm_notifications_user ON public.crm_notifications(user_id);

-- Enable Supabase Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.crm_records;
ALTER PUBLICATION supabase_realtime ADD TABLE public.crm_notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.crm_profiles;

-- RLS Enablement
ALTER TABLE public.crm_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_notifications ENABLE ROW LEVEL SECURITY;

-- Helper security functions
CREATE OR REPLACE FUNCTION public.crm_get_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.crm_profiles WHERE id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- Helper to safely fetch partner IDs for channel partner RLS without recursion
CREATE OR REPLACE FUNCTION public.crm_get_partner_ids_for_user(p_uid UUID)
RETURNS SETOF UUID AS $$
    SELECT id FROM public.crm_records 
    WHERE entity_type = 'partner' AND (assigned_to = p_uid OR created_by = p_uid);
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public;

-- RLS for crm_profiles
DROP POLICY IF EXISTS "profiles_select_policy" ON public.crm_profiles;
CREATE POLICY "profiles_select_policy" ON public.crm_profiles
    FOR SELECT TO authenticated
    USING (
        public.crm_get_user_role() IN ('admin_founder', 'founder') 
        OR id = auth.uid()
    );

DROP POLICY IF EXISTS "profiles_admin_all_policy" ON public.crm_profiles;
CREATE POLICY "profiles_admin_all_policy" ON public.crm_profiles
    FOR ALL TO authenticated
    USING (public.crm_get_user_role() = 'admin_founder')
    WITH CHECK (public.crm_get_user_role() = 'admin_founder');

DROP POLICY IF EXISTS "profiles_update_self_policy" ON public.crm_profiles;
CREATE POLICY "profiles_update_self_policy" ON public.crm_profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- RLS for crm_records
DROP POLICY IF EXISTS "records_founders_policy" ON public.crm_records;
CREATE POLICY "records_founders_policy" ON public.crm_records
    FOR ALL TO authenticated
    USING (
        public.crm_get_user_role() IN ('admin_founder', 'founder')
    )
    WITH CHECK (
        public.crm_get_user_role() IN ('admin_founder', 'founder')
    );

DROP POLICY IF EXISTS "records_partner_select_policy" ON public.crm_records;
CREATE POLICY "records_partner_select_policy" ON public.crm_records
    FOR SELECT TO authenticated
    USING (
        public.crm_get_user_role() = 'channel_partner'
        AND (
            assigned_to = auth.uid() 
            OR created_by = auth.uid()
            OR partner_id IN (SELECT public.crm_get_partner_ids_for_user(auth.uid()))
        )
    );

DROP POLICY IF EXISTS "records_partner_insert_policy" ON public.crm_records;
CREATE POLICY "records_partner_insert_policy" ON public.crm_records
    FOR INSERT TO authenticated
    WITH CHECK (
        public.crm_get_user_role() = 'channel_partner'
        AND entity_type IN ('lead', 'partner_visit')
        AND created_by = auth.uid()
    );

-- RLS for crm_notifications
DROP POLICY IF EXISTS "notifications_user_policy" ON public.crm_notifications;
CREATE POLICY "notifications_user_policy" ON public.crm_notifications
    FOR ALL TO authenticated
    USING (user_id = auth.uid() OR public.crm_get_user_role() IN ('admin_founder', 'founder'))
    WITH CHECK (user_id = auth.uid() OR public.crm_get_user_role() IN ('admin_founder', 'founder'));

-- Activity log trigger
CREATE OR REPLACE FUNCTION public.crm_record_activity_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_user_name TEXT := 'System';
    v_action TEXT;
BEGIN
    IF auth.uid() IS NOT NULL THEN
        SELECT name INTO v_user_name FROM public.crm_profiles WHERE id = auth.uid();
        IF v_user_name IS NULL THEN
            v_user_name := 'User ' || SUBSTRING(auth.uid()::text, 1, 6);
        END IF;
    END IF;

    IF (TG_OP = 'INSERT') THEN
        IF NEW.entity_type != 'activity_log' THEN
            INSERT INTO public.crm_records (entity_type, title, description, team, extra_data, created_by)
            VALUES (
                'activity_log',
                v_user_name || ' created ' || NEW.entity_type || ' "' || NEW.title || '"',
                'New ' || NEW.entity_type || ' registered in ' || COALESCE(NEW.team, 'Gulbarga'),
                COALESCE(NEW.team, 'Both'),
                jsonb_build_object('actor_name', v_user_name, 'action', 'create', 'target_id', NEW.id, 'target_type', NEW.entity_type),
                NEW.created_by
            );
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF NEW.entity_type != 'activity_log' AND OLD.entity_type != 'activity_log' THEN
            INSERT INTO public.crm_records (entity_type, title, description, team, extra_data, created_by)
            VALUES (
                'activity_log',
                v_user_name || ' updated ' || NEW.entity_type || ' "' || NEW.title || '"',
                'Status: ' || COALESCE(NEW.status, 'updated'),
                COALESCE(NEW.team, 'Both'),
                jsonb_build_object('actor_name', v_user_name, 'action', 'update', 'target_id', NEW.id, 'target_type', NEW.entity_type),
                auth.uid()
            );
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.entity_type != 'activity_log' THEN
            INSERT INTO public.crm_records (entity_type, title, description, team, extra_data, created_by)
            VALUES (
                'activity_log',
                v_user_name || ' deleted ' || OLD.entity_type || ' "' || OLD.title || '"',
                'Removed from CRM',
                COALESCE(OLD.team, 'Both'),
                jsonb_build_object('actor_name', v_user_name, 'action', 'delete', 'target_id', OLD.id, 'target_type', OLD.entity_type),
                auth.uid()
            );
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_crm_record_activity ON public.crm_records;
CREATE TRIGGER trg_crm_record_activity
    AFTER INSERT OR UPDATE OR DELETE ON public.crm_records
    FOR EACH ROW EXECUTE FUNCTION public.crm_record_activity_trigger();

-- Seed / Admin Management RPC Functions
CREATE OR REPLACE FUNCTION public.crm_seed_admin(
    p_mobile TEXT,
    p_password TEXT,
    p_name TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_email TEXT := p_mobile || '@opensoftwares.app';
    v_encrypted_pw TEXT;
BEGIN
    v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf'));

    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

    IF v_user_id IS NULL THEN
        v_user_id := gen_random_uuid();
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_email,
            v_encrypted_pw,
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('name', p_name, 'mobile', p_mobile, 'role', 'admin_founder'),
            now(),
            now()
        );
    ELSE
        UPDATE auth.users 
        SET encrypted_password = v_encrypted_pw, updated_at = now() 
        WHERE id = v_user_id;
    END IF;

    INSERT INTO public.crm_profiles (
        id, mobile_number, name, role, team, is_disabled, first_login_change_required
    ) VALUES (
        v_user_id, p_mobile, p_name, 'admin_founder', 'Both', false, false
    ) ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        role = 'admin_founder',
        team = 'Both',
        is_disabled = false;

    RETURN jsonb_build_object('success', true, 'user_id', v_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin Create User RPC (for Admin Founder use)
CREATE OR REPLACE FUNCTION public.crm_admin_create_user(
    p_mobile TEXT,
    p_password TEXT,
    p_name TEXT,
    p_role TEXT,
    p_team TEXT,
    p_permissions JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_email TEXT := p_mobile || '@opensoftwares.app';
    v_encrypted_pw TEXT;
    v_perm JSONB := COALESCE(p_permissions, '{
        "tabs": ["home", "pipeline", "products", "profile"],
        "modules": {
            "tasks": {"create": true, "edit": true, "delete": true},
            "products": {"create": true, "edit": true, "delete": true},
            "leads": {"create": true, "edit": true, "delete": true},
            "partners": {"create": true, "edit": true, "delete": true},
            "collections": {"create": true, "edit": true, "delete": true},
            "meetings": {"create": true, "edit": true, "delete": true},
            "notices": {"create": true, "edit": true, "delete": true}
        }
    }'::jsonb);
BEGIN
    IF public.crm_get_user_role() != 'admin_founder' AND auth.uid() IS NOT NULL THEN
        RAISE EXCEPTION 'Access denied. Admin Founder role required.';
    END IF;

    v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf'));

    SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

    IF v_user_id IS NOT NULL THEN
        UPDATE auth.users 
        SET encrypted_password = v_encrypted_pw, updated_at = now()
        WHERE id = v_user_id;

        UPDATE public.crm_profiles SET
            name = p_name,
            role = p_role,
            team = p_team,
            permissions = v_perm,
            is_disabled = false,
            updated_at = now()
        WHERE id = v_user_id;
    ELSE
        v_user_id := gen_random_uuid();
        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
            confirmation_token, recovery_token, email_change_token_new, email_change,
            phone_change_token, reauthentication_token, email_change_token_current, phone_change
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            v_user_id,
            'authenticated',
            'authenticated',
            v_email,
            v_encrypted_pw,
            now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('name', p_name, 'mobile', p_mobile, 'role', p_role),
            now(),
            now(),
            '', '', '', '', '', '', '', ''
        );

        INSERT INTO auth.identities (
            id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id::text,
            v_user_id,
            jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false),
            'email',
            now(),
            now(),
            now()
        ) ON CONFLICT (provider, provider_id) DO NOTHING;

        INSERT INTO public.crm_profiles (
            id, mobile_number, name, role, team, permissions, is_disabled
        ) VALUES (
            v_user_id, p_mobile, p_name, p_role, p_team, v_perm, false
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'user_id', v_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- Admin Update User RPC
CREATE OR REPLACE FUNCTION public.crm_admin_update_user(
    p_user_id UUID,
    p_name TEXT,
    p_role TEXT,
    p_team TEXT,
    p_permissions JSONB,
    p_is_disabled BOOLEAN,
    p_new_password TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF public.crm_get_user_role() != 'admin_founder' THEN
        RAISE EXCEPTION 'Access denied. Admin Founder role required.';
    END IF;

    UPDATE public.crm_profiles SET
        name = COALESCE(p_name, name),
        role = COALESCE(p_role, role),
        team = COALESCE(p_team, team),
        permissions = COALESCE(p_permissions, permissions),
        is_disabled = COALESCE(p_is_disabled, is_disabled),
        updated_at = now()
    WHERE id = p_user_id;

    IF p_new_password IS NOT NULL AND length(trim(p_new_password)) > 0 THEN
        UPDATE auth.users 
        SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
            updated_at = now()
        WHERE id = p_user_id;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Quick Alert Ack RPC
CREATE OR REPLACE FUNCTION public.crm_acknowledge_alert(
    p_alert_id UUID,
    p_user_id UUID,
    p_user_name TEXT,
    p_action TEXT DEFAULT 'Seen'
)
RETURNS JSONB AS $$
DECLARE
    v_extra JSONB;
    v_acks JSONB;
    v_new_ack JSONB;
BEGIN
    SELECT extra_data INTO v_extra FROM public.crm_records WHERE id = p_alert_id;
    IF v_extra IS NULL THEN
        v_extra := '{}'::jsonb;
    END IF;
    
    v_acks := COALESCE(v_extra->'acknowledged_by', '[]'::jsonb);
    v_new_ack := jsonb_build_object(
        'user_id', p_user_id,
        'name', p_user_name,
        'action', p_action,
        'time', now()
    );
    
    v_extra := jsonb_set(v_extra, '{acknowledged_by}', v_acks || v_new_ack);

    UPDATE public.crm_records SET extra_data = v_extra, updated_at = now() WHERE id = p_alert_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

