-- Enable pg_cron extension (requires Supabase Pro or enabling in Dashboard)
-- Dashboard: Database → Extensions → search "pg_cron" → Enable

-- Run stock alert check every hour
select cron.schedule(
  'check-stock-alerts-hourly',
  '0 * * * *',
  $$
    select net.http_post(
      url     := current_setting('app.supabase_url') || '/functions/v1/check-stock-alerts',
      headers := jsonb_build_object(
        'Content-Type',       'application/json',
        'Authorization',      'Bearer ' || current_setting('app.service_role_key'),
        'x-internal-secret',  current_setting('app.internal_function_secret')
      ),
      body    := '{}'::jsonb
    );
  $$
);
