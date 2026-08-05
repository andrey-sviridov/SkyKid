-- SkyKid — совместный доступ двух родителей к одному ребёнку.
--
-- Выполнить целиком в Supabase SQL Editor. Скрипт идемпотентный и
-- безопасен для уже существующих данных: каждой имеющейся строке заводится
-- собственная «семья», владелец становится её первым участником, и ничего
-- не теряется.
--
-- Модель: данные принадлежат не пользователю, а СЕМЬЕ (`families`).
-- Пользователи входят в семью через `family_members`. Второй родитель
-- присоединяется по одноразовому приглашению.
--
-- Имя ребёнка остаётся зашифрованным: ключ AES-GCM передаётся внутри
-- кода приглашения, который родители пересылают друг другу сами. Сервер
-- ключа по-прежнему не видит — `redeem_family_invite()` про него не знает.

-- ── Семьи и участники ───────────────────────────────────────────────────

create table if not exists public.families (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id  uuid not null references public.families(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index if not exists family_members_user_id_idx
  on public.family_members (user_id);

create table if not exists public.family_invites (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families(id) on delete cascade,
  created_by   uuid not null references auth.users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default now() + interval '7 days',
  redeemed_at  timestamptz,
  redeemed_by  uuid references auth.users(id)
);

create index if not exists family_invites_family_id_idx
  on public.family_invites (family_id);

-- ── Проверка членства ───────────────────────────────────────────────────
-- security definer обязателен: политика на `family_members`, которая сама
-- читает `family_members`, уходит в бесконечную рекурсию RLS. Функция
-- выполняется с правами владельца и рекурсию разрывает.

create or replace function public.is_family_member(fid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.family_members
     where family_id = fid and user_id = auth.uid()
  );
$$;

revoke all on function public.is_family_member(uuid) from public;
grant execute on function public.is_family_member(uuid) to authenticated;

-- ── RLS: видно только свою семью ────────────────────────────────────────

alter table public.families       enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invites enable row level security;

drop policy if exists families_select_own on public.families;
create policy families_select_own
  on public.families for select
  using (public.is_family_member(id));

drop policy if exists family_members_select_own on public.family_members;
create policy family_members_select_own
  on public.family_members for select
  using (public.is_family_member(family_id));

-- Выйти из семьи можно только самому за себя.
drop policy if exists family_members_delete_self on public.family_members;
create policy family_members_delete_self
  on public.family_members for delete
  using (user_id = auth.uid());

drop policy if exists family_invites_select_own on public.family_invites;
create policy family_invites_select_own
  on public.family_invites for select
  using (public.is_family_member(family_id));

drop policy if exists family_invites_insert_own on public.family_invites;
create policy family_invites_insert_own
  on public.family_invites for insert
  with check (public.is_family_member(family_id) and created_by = auth.uid());

drop policy if exists family_invites_delete_own on public.family_invites;
create policy family_invites_delete_own
  on public.family_invites for delete
  using (public.is_family_member(family_id));

-- Строки создаются только через RPC ниже, поэтому insert-политик на
-- families/family_members намеренно нет.
grant select                on public.families       to authenticated;
grant select, delete        on public.family_members to authenticated;
grant select, insert, delete on public.family_invites to authenticated;

-- ── RPC: своя семья и присоединение по приглашению ──────────────────────

create or replace function public.ensure_family()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  fid uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select family_id into fid
    from public.family_members
   where user_id = auth.uid()
   limit 1;

  if fid is not null then
    return fid;
  end if;

  insert into public.families default values returning id into fid;
  insert into public.family_members (family_id, user_id) values (fid, auth.uid());
  return fid;
end;
$$;

revoke all on function public.ensure_family() from public;
grant execute on function public.ensure_family() to authenticated;

create or replace function public.redeem_family_invite(invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  fid uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select family_id into fid
    from public.family_invites
   where id = invite_id
     and redeemed_at is null
     and expires_at > now();

  if fid is null then
    raise exception 'invite_invalid_or_expired';
  end if;

  -- Присоединяющийся мог уже состоять в собственной семье (он же —
  -- владелец своих данных). Его прежнее членство снимается, иначе
  -- ensure_family() потом вернёт не ту семью. Сами данные прежней семьи
  -- НЕ удаляются: строки остаются на месте, просто перестают быть видны.
  delete from public.family_members
   where user_id = auth.uid() and family_id <> fid;

  insert into public.family_members (family_id, user_id)
  values (fid, auth.uid())
  on conflict (family_id, user_id) do nothing;

  update public.family_invites
     set redeemed_at = now(), redeemed_by = auth.uid()
   where id = invite_id;

  return fid;
end;
$$;

revoke all on function public.redeem_family_invite(uuid) from public;
grant execute on function public.redeem_family_invite(uuid) to authenticated;

-- ── Перевод данных ребёнка на семью ─────────────────────────────────────

alter table public.child_profiles
  add column if not exists family_id uuid references public.families(id) on delete cascade;

alter table public.walk_logs
  add column if not exists family_id uuid references public.families(id) on delete cascade;

-- Бэкфилл: каждому владельцу существующих строк — своя семья.
do $$
declare
  r record;
  fid uuid;
begin
  for r in
    select distinct user_id from public.child_profiles where family_id is null
    union
    select distinct user_id from public.walk_logs where family_id is null
  loop
    select family_id into fid
      from public.family_members where user_id = r.user_id limit 1;

    if fid is null then
      insert into public.families default values returning id into fid;
      insert into public.family_members (family_id, user_id) values (fid, r.user_id);
    end if;

    update public.child_profiles set family_id = fid
     where user_id = r.user_id and family_id is null;
    update public.walk_logs set family_id = fid
     where user_id = r.user_id and family_id is null;
  end loop;
end;
$$;

-- Один профиль ребёнка на семью: первичный ключ переезжает с владельца на
-- семью, а `user_id` остаётся отметкой «кто последним сохранил».
alter table public.child_profiles alter column family_id set not null;
alter table public.walk_logs      alter column family_id set not null;

do $$
begin
  if exists (
    select 1 from pg_constraint
     where conname = 'child_profiles_pkey' and conrelid = 'public.child_profiles'::regclass
  ) and not exists (
    select 1 from pg_index i
      join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey)
     where i.indrelid = 'public.child_profiles'::regclass
       and i.indisprimary and a.attname = 'family_id'
  ) then
    alter table public.child_profiles drop constraint child_profiles_pkey;
    alter table public.child_profiles add primary key (family_id);
  end if;
end;
$$;

create index if not exists walk_logs_family_id_idx on public.walk_logs (family_id);

-- ── RLS данных ребёнка: по членству в семье, а не по владельцу ──────────

drop policy if exists child_profiles_select_own on public.child_profiles;
drop policy if exists child_profiles_insert_own on public.child_profiles;
drop policy if exists child_profiles_update_own on public.child_profiles;
drop policy if exists child_profiles_delete_own on public.child_profiles;

create policy child_profiles_select_family
  on public.child_profiles for select
  using (public.is_family_member(family_id));

create policy child_profiles_insert_family
  on public.child_profiles for insert
  with check (public.is_family_member(family_id));

create policy child_profiles_update_family
  on public.child_profiles for update
  using (public.is_family_member(family_id))
  with check (public.is_family_member(family_id));

create policy child_profiles_delete_family
  on public.child_profiles for delete
  using (public.is_family_member(family_id));

drop policy if exists walk_logs_select_own on public.walk_logs;
drop policy if exists walk_logs_insert_own on public.walk_logs;
drop policy if exists walk_logs_update_own on public.walk_logs;
drop policy if exists walk_logs_delete_own on public.walk_logs;

create policy walk_logs_select_family
  on public.walk_logs for select
  using (public.is_family_member(family_id));

create policy walk_logs_insert_family
  on public.walk_logs for insert
  with check (public.is_family_member(family_id));

create policy walk_logs_update_family
  on public.walk_logs for update
  using (public.is_family_member(family_id))
  with check (public.is_family_member(family_id));

create policy walk_logs_delete_family
  on public.walk_logs for delete
  using (public.is_family_member(family_id));
