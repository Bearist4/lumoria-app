-- Rewire the notifications → send-push trigger to read its config from
-- Supabase Vault instead of `ALTER DATABASE … SET app.*`.
--
-- Hosted Supabase blocks `ALTER DATABASE postgres SET app.xxx`, so the
-- original approach in 20260423000000_push_notifications.sql can't land
-- on the cloud. Vault is the supported alternative.
--
-- Prereq (run once in the SQL editor before applying this migration):
--
--   select vault.create_secret(
--     'https://<PROJECT_REF>.supabase.co/functions/v1/send-push',
--     'send_push_function_url',
--     'Edge function URL for APNs fan-out trigger'
--   );
--   select vault.create_secret(
--     '<SERVICE_ROLE_KEY>',
--     'send_push_service_role_key',
--     'Service role key for the send-push edge function'
--   );
--
-- To rotate either value, `update vault.secrets set secret = '...' where name = '...';`.

create or replace function public.notifications_fanout_push()
returns trigger
language plpgsql
security definer
set search_path = public, vault
as $$
declare
    fn_url  text;
    sr_key  text;
    payload jsonb;
begin
    select decrypted_secret
      into fn_url
      from vault.decrypted_secrets
     where name = 'send_push_function_url'
     limit 1;

    select decrypted_secret
      into sr_key
      from vault.decrypted_secrets
     where name = 'send_push_service_role_key'
     limit 1;

    -- Best-effort. If either secret is missing, skip the push; the
    -- notification still shows up in the app on next fetch.
    if fn_url is null or sr_key is null then
        return new;
    end if;

    payload := jsonb_build_object('notification_id', new.id);

    perform
        net.http_post(
            url     := fn_url,
            headers := jsonb_build_object(
                'Content-Type',  'application/json',
                'Authorization', 'Bearer ' || sr_key
            ),
            body    := payload
        );

    return new;
end;
$$;

comment on function public.notifications_fanout_push() is
  'Calls the send-push edge function whenever a notification is inserted. Reads URL + service-role key from Supabase Vault (names: send_push_function_url, send_push_service_role_key).';
