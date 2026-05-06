-- Self-service early-adopter seats. "Early adopter" is the user-facing
-- label for a grandfathered profile (`profiles.grandfathered_at IS NOT
-- NULL`). Same column, same caps bypass — just self-claimed via this
-- RPC instead of admin-stamped from the waitlist.
--
-- Cap is bumped to 300 here (was 100 in 20260505000000_grandfather_beta_testers).
-- The waitlist-driven auto-stamp inside `handle_new_user` and the
-- self-service `claim_early_adopter_seat` both share the same 300-seat
-- pool, gated by an advisory lock so two simultaneous calls can't both
-- squeak past the ceiling. The existing `profiles_protect_grandfather`
-- trigger keeps the column read-only for the `authenticated` role; the
-- SECURITY DEFINER RPCs run as the definer and bypass the trigger.

-- Seats remaining (0..300). Anyone signed-in can call this.
CREATE OR REPLACE FUNCTION public.early_adopter_seats_remaining()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
STABLE
AS $function$
DECLARE
  v_taken integer;
  v_cap   constant integer := 300;
BEGIN
  SELECT count(*) INTO v_taken
    FROM public.profiles
   WHERE grandfathered_at IS NOT NULL;
  RETURN GREATEST(v_cap - v_taken, 0);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.early_adopter_seats_remaining() TO authenticated;

-- Atomic claim. Idempotent if the caller is already grandfathered.
-- Raises `no_seats_remaining` when the pool is empty.
CREATE OR REPLACE FUNCTION public.claim_early_adopter_seat()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid   uuid := auth.uid();
  v_taken integer;
  v_cap   constant integer := 300;
  v_stamp TIMESTAMPTZ;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Idempotent fast-path.
  SELECT grandfathered_at INTO v_stamp
    FROM public.profiles
   WHERE user_id = v_uid;
  IF v_stamp IS NOT NULL THEN
    RETURN v_stamp;
  END IF;

  -- Same advisory key as `handle_new_user` so the waitlist auto-stamp
  -- and the self-service claim serialise against each other.
  PERFORM pg_advisory_xact_lock(hashtext('lumoria_grandfather_seat'));

  SELECT count(*) INTO v_taken
    FROM public.profiles
   WHERE grandfathered_at IS NOT NULL;

  IF v_taken >= v_cap THEN
    RAISE EXCEPTION 'no_seats_remaining';
  END IF;

  UPDATE public.profiles
     SET grandfathered_at = now()
   WHERE user_id = v_uid
   RETURNING grandfathered_at INTO v_stamp;

  RETURN v_stamp;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.claim_early_adopter_seat() TO authenticated;

-- Self-revoke — frees the seat for someone else immediately.
CREATE OR REPLACE FUNCTION public.revoke_early_adopter_seat()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  UPDATE public.profiles
     SET grandfathered_at = NULL
   WHERE user_id = v_uid;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.revoke_early_adopter_seat() TO authenticated;

-- Bump the auto-stamp cap inside `handle_new_user` from 100 → 300 so
-- the waitlist trigger and the self-service RPC share the same pool.
-- Body is otherwise identical to 20260505000000_grandfather_beta_testers.
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

    IF v_count < 300 THEN
      UPDATE public.profiles
         SET grandfathered_at = now()
       WHERE user_id = NEW.id;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;
