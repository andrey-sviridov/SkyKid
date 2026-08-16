-- SkyKid — родители видят, кто ещё в семье.
--
-- Выполнить целиком в Supabase SQL Editor после
-- `2026-08-04-family-sharing.sql`. Скрипт идемпотентный.
--
-- Проблема: `family_members` хранит только `user_id`, а `auth.users`
-- клиенту недоступна — RLS-политики на неё не распространяются, и
-- PostgREST её не отдаёт. Поэтому имя/почту участников отдаёт отдельная
-- `security definer` функция, которая сама ограничивает выдачу семьёй
-- вызывающего.
--
-- Что видно: имя из профиля провайдера входа (Google отдаёт `full_name`),
-- почта, аватарка и способ входа. Это данные только участников СВОЕЙ
-- семьи — общий доступ к `auth.users` функция не открывает.

create or replace function public.family_members_info()
returns table (
  user_id      uuid,
  email        text,
  display_name text,
  avatar_url   text,
  provider     text,
  joined_at    timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    m.user_id,
    u.email::text,
    nullif(
      btrim(coalesce(
        u.raw_user_meta_data->>'full_name',
        u.raw_user_meta_data->>'name',
        ''
      )),
      ''
    ),
    nullif(btrim(coalesce(u.raw_user_meta_data->>'avatar_url', '')), ''),
    nullif(btrim(coalesce(u.raw_app_meta_data->>'provider', '')), ''),
    -- Порядок списка: пригласивший идёт первым. Клиент это поле не читает,
    -- но по нему сортируется выдача.
    m.joined_at
  from public.family_members m
  join auth.users u on u.id = m.user_id
  where auth.uid() is not null
    and m.family_id in (
      select fm.family_id
        from public.family_members fm
       where fm.user_id = auth.uid()
    )
  order by m.joined_at;
$$;

revoke all on function public.family_members_info() from public;
grant execute on function public.family_members_info() to authenticated;
