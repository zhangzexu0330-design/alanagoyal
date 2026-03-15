-- 1. Allow session owner to toggle public/private
CREATE OR REPLACE FUNCTION public.update_note_public(uuid_arg uuid, session_arg uuid, public_arg boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE public.notes
    SET public = public_arg
    WHERE id = uuid_arg AND session_id = session_arg;
END;
$function$;

-- 2. Ensure note-images storage bucket exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'note-images', 'note-images', true, 5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- 3. Storage policies (idempotent)
DROP POLICY IF EXISTS "Public read access for note images" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to upload note images" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own note images" ON storage.objects;

CREATE POLICY "Public read access for note images" ON storage.objects
  FOR SELECT USING (bucket_id = 'note-images');
CREATE POLICY "Allow users to upload note images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'note-images');
CREATE POLICY "Allow users to delete their own note images" ON storage.objects
  FOR DELETE USING (bucket_id = 'note-images');
