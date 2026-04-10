from supabase import Client, create_client

from app.core.config import settings

# Service-role client — bypasses RLS.
# ALWAYS filter by user_id in every query; never expose this client to the frontend.
# Never call supabase.auth.sign_in_* on this client — it sets a session that overrides
# the service key and expires after 1 hour (PGRST303). Use supabase_auth for auth ops.
supabase: Client = create_client(settings.supabase_url, settings.supabase_service_key)

# Separate client for auth operations only (sign_up, sign_in_with_password).
# Kept separate so session state never bleeds into the service-role client.
supabase_auth: Client = create_client(settings.supabase_url, settings.supabase_service_key)
