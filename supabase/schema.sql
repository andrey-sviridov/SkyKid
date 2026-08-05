-- SkyKid — схема Supabase для синхронизации ChildProfile + WalkLog.
-- Выполнить целиком в Supabase SQL Editor (Dashboard → SQL Editor → New query),
-- а СРАЗУ ПОСЛЕ — migrations/2026-08-04-family-sharing.sql: он переводит
-- данные с владельца-пользователя на семью (совместный доступ двух
-- родителей) и переписывает RLS соответствующим образом. Этот файл описывает
-- только исходное состояние и без миграции неполон.
--
-- Обе таблицы защищены RLS по auth.uid(): пользователь видит и меняет
-- только свои строки. Имя ребёнка (`encrypted_name`) шифруется AES-GCM на
-- устройстве до отправки — Supabase хранит только шифротекст и nonce,
-- ключ шифрования никогда не покидает устройство (iCloud Keychain).

-- ── child_profiles: одна строка на пользователя ─────────────────────────

create table public.child_profiles (
  user_id                         uuid primary key references auth.users(id) on delete cascade,
  encrypted_name                  text not null,  -- AES-GCM combined (nonce+ciphertext+tag), base64
  gender                          text not null,
  birthday                        date not null,
  gestational_age_weeks           int not null,
  stable_traits                   text[] not null default '{}',
  temperature_preference_offset   double precision not null default 0,
  schema_version                  int not null default 2,
  updated_at                      timestamptz not null default now()
);

alter table public.child_profiles enable row level security;

create policy "child_profiles_select_own"
  on public.child_profiles for select
  using (auth.uid() = user_id);

create policy "child_profiles_insert_own"
  on public.child_profiles for insert
  with check (auth.uid() = user_id);

create policy "child_profiles_update_own"
  on public.child_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "child_profiles_delete_own"
  on public.child_profiles for delete
  using (auth.uid() = user_id);

-- RLS ограничивает строки, но не выдаёт прав на саму таблицу: без GRANT
-- PostgREST отвечает 403 / 42501 «permission denied for table», не доходя
-- до политик. Права выдаются только вошедшим (`authenticated`) — `anon`
-- доступа к детским данным не имеет вовсе.
grant select, insert, update, delete on public.child_profiles to authenticated;

-- ── walk_logs: много строк на пользователя ──────────────────────────────
-- id совпадает с локальным WalkLog.id (UUID) — это делает push идемпотентным
-- (upsert по первичному ключу вместо append-only insert).

create table public.walk_logs (
  id                        uuid primary key,
  user_id                   uuid not null references auth.users(id) on delete cascade,
  date                      timestamptz not null,
  duration_minutes          int not null,
  outfit_item_ids           text[] not null default '{}',
  comfort_level             text not null,
  weather_temperature       double precision not null,
  apparent_temperature      double precision not null,
  microclimate_temperature  double precision,
  transport_mode            text,
  activity_level            text,
  walk_type                 text,
  target_tog                double precision,
  effective_outfit_tog      double precision,
  events                    jsonb not null default '[]',
  is_live_tracked           boolean not null default false,
  weather_code              int,
  planned_duration_minutes  int,
  updated_at                timestamptz not null default now()
);

create index walk_logs_user_id_idx on public.walk_logs (user_id);

alter table public.walk_logs enable row level security;

create policy "walk_logs_select_own"
  on public.walk_logs for select
  using (auth.uid() = user_id);

create policy "walk_logs_insert_own"
  on public.walk_logs for insert
  with check (auth.uid() = user_id);

create policy "walk_logs_update_own"
  on public.walk_logs for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "walk_logs_delete_own"
  on public.walk_logs for delete
  using (auth.uid() = user_id);

-- См. комментарий к grant для child_profiles.
grant select, insert, update, delete on public.walk_logs to authenticated;
