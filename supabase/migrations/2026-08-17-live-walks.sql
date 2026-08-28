-- SkyKid — второй родитель видит идущую прогулку в реальном времени.
--
-- Выполнить целиком в Supabase SQL Editor после
-- `2026-08-04-family-sharing.sql`. Скрипт идемпотентный.
--
-- До этой миграции на сервер попадала только ЗАВЕРШЁННАЯ прогулка
-- (`walk_logs` после `finish()`), а идущая жила исключительно в App Group на
-- устройстве владельца. Здесь появляется её серверное отражение — с
-- Realtime-публикацией, чтобы второй родитель видел таймлайн, пока прогулка
-- ещё идёт.
--
-- Строка живёт ровно столько, сколько идёт прогулка: при завершении или
-- отмене клиент её удаляет, а сама прогулка приезжает вторым путём — как
-- обычный `walk_logs`-апсерт. Двух источников правды по завершённым
-- прогулкам не заводим.

-- ── Слот живой прогулки ─────────────────────────────────────────────────
-- Первичный ключ (family_id, user_id), а не (family_id): оба родителя могут
-- гулять одновременно, и слот у каждого свой — иначе они затирали бы друг
-- друга. И не (walk_id): тогда «старт → отмена → старт» оставлял бы
-- висящие строки, и понадобился бы отдельный cleanup.

create table if not exists public.live_walks (
  family_id                 uuid not null references public.families(id) on delete cascade,
  user_id                   uuid not null references auth.users(id)      on delete cascade,
  walk_id                   uuid not null,          -- = ActiveWalk.id
  started_at                timestamptz not null,   -- = ActiveWalk.startDate
  planned_duration_minutes  int,
  -- Денормализованные скаляры: текст уведомления и счётчик отметок в списке
  -- не должны разбирать payload.
  event_count               int  not null default 0,
  last_event_kind           text,                   -- WalkEventKind.rawValue
  last_event_at             timestamptz,
  payload                   jsonb not null,         -- весь ActiveWalk, как его кодирует клиент
  updated_at                timestamptz not null default now(),
  primary key (family_id, user_id)
);

-- Отдельный индекс по family_id не нужен — это ведущая колонка первичного
-- ключа, и запросы вида `where family_id = ?` идут по нему же.

-- ── RLS ─────────────────────────────────────────────────────────────────
-- Через ту же `security definer` функцию `is_family_member`, что и
-- остальные таблицы: прямая политика, читающая family_members из политики
-- на family_members, уходит в бесконечную рекурсию.

alter table public.live_walks enable row level security;

drop policy if exists live_walks_select_family on public.live_walks;
create policy live_walks_select_family
  on public.live_walks for select
  using (public.is_family_member(family_id));

-- Писать — только в свой слот, иначе один родитель мог бы подменить
-- прогулку другого.
drop policy if exists live_walks_insert_own on public.live_walks;
create policy live_walks_insert_own
  on public.live_walks for insert
  with check (public.is_family_member(family_id) and user_id = auth.uid());

drop policy if exists live_walks_update_own on public.live_walks;
create policy live_walks_update_own
  on public.live_walks for update
  using      (public.is_family_member(family_id) and user_id = auth.uid())
  with check (public.is_family_member(family_id) and user_id = auth.uid());

-- Удалять может любой член семьи: если у владельца приложение умерло
-- посреди прогулки, второй родитель должен уметь убрать «призрак».
drop policy if exists live_walks_delete_family on public.live_walks;
create policy live_walks_delete_family
  on public.live_walks for delete
  using (public.is_family_member(family_id));

-- Без GRANT PostgREST отвечает 403/42501, не доходя до политик.
grant select, insert, update, delete on public.live_walks to authenticated;

-- ── Свежесть строки считает сервер ──────────────────────────────────────
-- `default now()` срабатывает только на INSERT, а апдейтов у слота много.
-- Без триггера `updated_at` замер бы на моменте старта, и наблюдатель не
-- смог бы отличить живую прогулку от «призрака» после краша. Часам
-- телефона это доверять нельзя — при расхождении на пару часов чужая
-- прогулка либо не покажется, либо застрянет навсегда.

create or replace function public.touch_live_walks_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists live_walks_set_updated_at on public.live_walks;
create trigger live_walks_set_updated_at
  before insert or update on public.live_walks
  for each row execute function public.touch_live_walks_updated_at();

-- ── Realtime ────────────────────────────────────────────────────────────

do $$
begin
  -- На проектах Supabase публикация уже есть, но скрипт должен пережить и
  -- пустую базу.
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename  = 'live_walks'
  ) then
    alter publication supabase_realtime add table public.live_walks;
  end if;
end;
$$;

-- Идентичность по первичному ключу, а НЕ `full`.
--
-- `postgres_changes` фильтрует DELETE по колонкам, попавшим в replica
-- identity. При `default` это колонки PK, а он начинается с `family_id` —
-- значит фильтр `family_id=eq.<uuid>` работает и на удалении. `full` гнал бы
-- весь payload в WAL на каждый апдейт ради данных, которые на удалении
-- всё равно не нужны.
--
-- Следствие для клиента: в `old_record` у DELETE приезжают ТОЛЬКО
-- family_id и user_id — полную строку оттуда доставать нельзя.
alter table public.live_walks replica identity default;
