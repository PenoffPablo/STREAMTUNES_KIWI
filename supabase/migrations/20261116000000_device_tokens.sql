-- ----------------------------------------------------------------------
-- Tokens FCM por dispositivo (notificaciones push con Firebase)
-- ----------------------------------------------------------------------
create table if not exists public.device_tokens (
    token text primary key,
    user_id uuid not null references public.profiles(id) on delete cascade,
    platform text not null default 'android',
    updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

-- Cada usuario gestiona SOLO los tokens de sus dispositivos.
-- La Edge Function `send-push` lee todos los tokens con la service role (sin RLS).
drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own" on public.device_tokens
    for select using ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_insert_own" on public.device_tokens;
create policy "device_tokens_insert_own" on public.device_tokens
    for insert with check ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_update_own" on public.device_tokens;
create policy "device_tokens_update_own" on public.device_tokens
    for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own" on public.device_tokens
    for delete using ((select auth.uid()) = user_id);
