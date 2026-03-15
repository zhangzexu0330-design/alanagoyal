-- ============================================================
-- Idempotent migration (safe to run multiple times)
-- ============================================================

-- notes table
create table if not exists "public"."notes" (
    "id" uuid not null default gen_random_uuid(),
    "title" text,
    "content" text,
    "created_at" timestamp with time zone not null default now(),
    "public" boolean,
    "session_id" uuid,
    "slug" text,
    "category" text,
    "emoji" text
);

alter table "public"."notes" enable row level security;

CREATE UNIQUE INDEX IF NOT EXISTS notes_pkey ON public.notes USING btree (id);
CREATE INDEX IF NOT EXISTS session_id_index ON public.notes USING btree (session_id);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notes_pkey'
  ) THEN
    alter table "public"."notes" add constraint "notes_pkey" PRIMARY KEY using index "notes_pkey";
  END IF;
END $$;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_note(uuid_arg uuid, session_arg uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    DELETE FROM public.notes
    WHERE id = uuid_arg AND session_id = session_arg;
END;
$function$;

CREATE OR REPLACE FUNCTION public.select_note(note_slug_arg text)
 RETURNS SETOF notes
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
    SELECT * FROM notes WHERE slug = note_slug_arg LIMIT 1;
$function$;

CREATE OR REPLACE FUNCTION public.select_session_notes(session_id_arg uuid)
 RETURNS SETOF notes
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
    SELECT * FROM notes WHERE session_id = session_id_arg;
$function$;

CREATE OR REPLACE FUNCTION public.update_note(uuid_arg uuid, session_arg uuid, title_arg text, emoji_arg text, content_arg text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE public.notes
    SET title = title_arg, emoji = emoji_arg, content = content_arg
    WHERE id = uuid_arg AND session_id = session_arg;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_note_content(uuid_arg uuid, session_arg uuid, content_arg text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE public.notes SET content = content_arg
    WHERE id = uuid_arg AND session_id = session_arg;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_note_emoji(uuid_arg uuid, session_arg uuid, emoji_arg text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE public.notes SET emoji = emoji_arg
    WHERE id = uuid_arg AND session_id = session_arg;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_note_title(uuid_arg uuid, session_arg uuid, title_arg text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE public.notes SET title = title_arg
    WHERE id = uuid_arg AND session_id = session_arg;
END;
$function$;

-- grants
grant delete, insert, references, select, trigger, truncate, update on table "public"."notes" to "anon";
grant delete, insert, references, select, trigger, truncate, update on table "public"."notes" to "authenticated";
grant delete, insert, references, select, trigger, truncate, update on table "public"."notes" to "service_role";

-- policies (drop first to avoid duplicates)
DROP POLICY IF EXISTS "allow_all_users_insert_private_notes" ON "public"."notes";
DROP POLICY IF EXISTS "allow_all_users_select_public_notes" ON "public"."notes";

create policy "allow_all_users_insert_private_notes"
on "public"."notes" as permissive for insert to public
with check ((public = false));

create policy "allow_all_users_select_public_notes"
on "public"."notes" as permissive for select to public
using ((public = true));

-- storage bucket for note-images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('note-images', 'note-images', true, 5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read access for note images" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload note images" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own note images" ON storage.objects;

CREATE POLICY "Public read access for note images" ON storage.objects FOR SELECT USING (bucket_id = 'note-images');
CREATE POLICY "Allow users to upload note images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'note-images');
CREATE POLICY "Allow users to delete their own note images" ON storage.objects FOR DELETE USING (bucket_id = 'note-images');

-- ============================================================
-- photos table
-- ============================================================
create table if not exists "public"."photos" (
    "id" uuid not null default gen_random_uuid(),
    "filename" text not null,
    "url" text not null,
    "timestamp" timestamp with time zone not null,
    "collections" text[] not null default '{}',
    "created_at" timestamp with time zone not null default now()
);

alter table "public"."photos" enable row level security;

CREATE UNIQUE INDEX IF NOT EXISTS photos_pkey ON public.photos USING btree (id);
CREATE INDEX IF NOT EXISTS photos_timestamp_idx ON public.photos USING btree (timestamp);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'photos_pkey'
  ) THEN
    alter table "public"."photos" add constraint "photos_pkey" PRIMARY KEY using index "photos_pkey";
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.select_photos()
 RETURNS SETOF photos
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
    SELECT * FROM photos ORDER BY timestamp ASC;
$function$;

CREATE OR REPLACE FUNCTION public.insert_photo(
    filename_arg text, url_arg text,
    timestamp_arg timestamp with time zone,
    collections_arg text[] DEFAULT '{}'
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE new_id uuid;
BEGIN
    INSERT INTO public.photos (filename, url, timestamp, collections)
    VALUES (filename_arg, url_arg, timestamp_arg, collections_arg)
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$function$;

grant select, insert on table "public"."photos" to "anon";
grant select, insert on table "public"."photos" to "authenticated";
grant all on table "public"."photos" to "service_role";

DROP POLICY IF EXISTS "allow_public_read_photos" ON "public"."photos";
DROP POLICY IF EXISTS "allow_insert_photos" ON "public"."photos";

create policy "allow_public_read_photos" on "public"."photos"
as permissive for select to public using (true);

create policy "allow_insert_photos" on "public"."photos"
as permissive for insert to public with check (true);

-- storage bucket for photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('photos', 'photos', true, 10485760,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read access for photos" ON storage.objects;
DROP POLICY IF EXISTS "Allow uploads to photos bucket" ON storage.objects;

CREATE POLICY "Public read access for photos" ON storage.objects FOR SELECT USING (bucket_id = 'photos');
CREATE POLICY "Allow uploads to photos bucket" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'photos');
