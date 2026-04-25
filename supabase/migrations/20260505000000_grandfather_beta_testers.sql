-- Beta-tester grandfathering. First 100 app sign-ups whose email is on
-- waitlist_subscribers get profiles.grandfathered_at stamped; the
-- timestamp grants lifetime free Premium without a StoreKit
-- subscription.
--
-- ALREADY APPLIED to the live DB via Supabase MCP on 2026-04-25.
-- This file is the repo-side record of that migration.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS grandfathered_at TIMESTAMPTZ;

WITH ranked AS (
  SELECT
    ws.supabase_user_id AS user_id,
    row_number() OVER (ORDER BY ws.created_at, ws.id) AS rn
  FROM public.waitlist_subscribers ws
  WHERE ws.supabase_user_id IS NOT NULL
)
UPDATE public.profiles p
   SET grandfathered_at = now()
  FROM ranked r
 WHERE p.user_id = r.user_id
   AND r.rn <= 100;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_count integer;
BEGIN
  INSERT INTO public.profiles (user_id) VALUES (NEW.id);

  PERFORM pg_advisory_xact_lock(hashtext('lumoria_grandfather_seat'));

  IF EXISTS (
    SELECT 1 FROM public.waitlist_subscribers
     WHERE supabase_user_id = NEW.id
  ) THEN
    SELECT count(*) INTO v_count
      FROM public.profiles
     WHERE grandfathered_at IS NOT NULL;

    IF v_count < 100 THEN
      UPDATE public.profiles
         SET grandfathered_at = now()
       WHERE user_id = NEW.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.profiles_protect_grandfather()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF current_user = 'authenticated'
     AND OLD.grandfathered_at IS DISTINCT FROM NEW.grandfathered_at
  THEN
    RAISE EXCEPTION 'grandfathered_at is read-only';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS profiles_protect_grandfather ON public.profiles;
CREATE TRIGGER profiles_protect_grandfather
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.profiles_protect_grandfather();
