-- River Academy: execute no SQL Editor de um projeto Supabase novo.
begin;
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 100),
  email text not null,
  role text not null default 'student' check (role in ('admin','student')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
create or replace function private.is_active_member() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles where id=(select auth.uid()) and active);
$$;
create or replace function private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles where id=(select auth.uid()) and active and role='admin');
$$;
revoke all on function private.is_active_member() from public,anon;
revoke all on function private.is_admin() from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.is_active_member(),private.is_admin() to authenticated;

create or replace function public.on_auth_user_created() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id,name,email,role,active)
 values(new.id,left(coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),split_part(new.email,'@',1),'Aluno'),100),coalesce(new.email,''),'student',true);
 return new;
end;
$$;
drop trigger if exists river_auth_user_created on auth.users;
create trigger river_auth_user_created after insert on auth.users for each row execute function public.on_auth_user_created();
revoke all on function public.on_auth_user_created() from public,anon,authenticated;
-- Backfill de contas que existiam antes de instalar o schema.
insert into public.profiles(id,name,email)
 select id,left(coalesce(nullif(trim(raw_user_meta_data->>'name'),''),split_part(email,'@',1),'Aluno'),100),coalesce(email,'') from auth.users
 on conflict(id) do nothing;

create table if not exists public.modules (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(trim(title)) between 1 and 120),
 description text not null default '',
 position integer not null default 1 check(position between 1 and 999),
 created_at timestamptz not null default now()
);
create table if not exists public.lessons (
 id uuid primary key default gen_random_uuid(),
 module_id uuid not null references public.modules(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 160),
 description text not null default '',
 video_url text not null default '',
 position integer not null default 1 check(position between 1 and 999),
 duration_minutes integer check(duration_minutes between 1 and 1440),
 created_at timestamptz not null default now()
);
create table if not exists public.lesson_progress (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 lesson_id uuid not null references public.lessons(id) on delete cascade,
 watched boolean not null default false,
 reviewed boolean not null default false,
 completed_at timestamptz,
 reviewed_at timestamptz,
 unique(user_id,lesson_id),
 check(not reviewed or watched)
);
create table if not exists public.questions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 module_id uuid references public.modules(id) on delete set null,
 title text not null check(length(trim(title)) between 1 and 180),
 description text not null check(length(trim(description)) between 1 and 10000),
 video_url text not null default '',
 resolved boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 question_id uuid not null references public.questions(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now()
);
create index if not exists lessons_module_idx on public.lessons(module_id,position);
create index if not exists progress_user_idx on public.lesson_progress(user_id);
create index if not exists progress_lesson_idx on public.lesson_progress(lesson_id);
create index if not exists questions_created_idx on public.questions(created_at desc);
create index if not exists questions_user_idx on public.questions(user_id);
create index if not exists questions_module_idx on public.questions(module_id);
create index if not exists comments_question_idx on public.comments(question_id,created_at);
create index if not exists comments_user_idx on public.comments(user_id);

-- O cliente nunca pode promover a própria conta ou alterar autoria.
create or replace function public.guard_profile_update() returns trigger language plpgsql set search_path='' as $$
begin
 if (select auth.uid()) is not null and not private.is_admin() then
  if new.id is distinct from old.id or new.role is distinct from old.role or new.active is distinct from old.active or new.email is distinct from old.email or new.created_at is distinct from old.created_at then
   raise exception 'Somente o administrador pode alterar os campos de acesso.';
  end if;
 end if;
 return new;
end;
$$;
create trigger river_guard_profile before update on public.profiles for each row execute function public.guard_profile_update();
revoke all on function public.guard_profile_update() from public,anon,authenticated;
create or replace function public.guard_author_update() returns trigger language plpgsql set search_path='' as $$
begin
 if new.user_id is distinct from old.user_id or new.created_at is distinct from old.created_at then
  raise exception 'Autoria e data de criação não podem ser alteradas.';
 end if;
 return new;
end;
$$;
create trigger river_guard_question before update on public.questions for each row execute function public.guard_author_update();
create trigger river_guard_comment before update on public.comments for each row execute function public.guard_author_update();
revoke all on function public.guard_author_update() from public,anon,authenticated;

alter table public.profiles enable row level security;
alter table public.modules enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.questions enable row level security;
alter table public.comments enable row level security;

-- Bloqueados podem ler apenas o próprio perfil para receber o aviso de bloqueio.
create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or private.is_active_member());
create policy profiles_update on public.profiles for update to authenticated using(private.is_admin() or (id=auth.uid() and private.is_active_member())) with check(private.is_admin() or (id=auth.uid() and private.is_active_member()));
create policy modules_read on public.modules for select to authenticated using(private.is_active_member());
create policy modules_create on public.modules for insert to authenticated with check(private.is_admin());
create policy modules_update on public.modules for update to authenticated using(private.is_admin()) with check(private.is_admin());
create policy modules_delete on public.modules for delete to authenticated using(private.is_admin());
create policy lessons_read on public.lessons for select to authenticated using(private.is_active_member());
create policy lessons_create on public.lessons for insert to authenticated with check(private.is_admin());
create policy lessons_update on public.lessons for update to authenticated using(private.is_admin()) with check(private.is_admin());
create policy lessons_delete on public.lessons for delete to authenticated using(private.is_admin());
create policy progress_read on public.lesson_progress for select to authenticated using(private.is_admin() or (user_id=auth.uid() and private.is_active_member()));
create policy progress_create on public.lesson_progress for insert to authenticated with check(user_id=auth.uid() and private.is_active_member());
create policy progress_update on public.lesson_progress for update to authenticated using(user_id=auth.uid() and private.is_active_member()) with check(user_id=auth.uid() and private.is_active_member());
create policy progress_delete on public.lesson_progress for delete to authenticated using(user_id=auth.uid() and private.is_active_member());
create policy questions_read on public.questions for select to authenticated using(private.is_active_member());
create policy questions_create on public.questions for insert to authenticated with check(user_id=auth.uid() and private.is_active_member());
create policy questions_update on public.questions for update to authenticated using(private.is_admin() or (user_id=auth.uid() and private.is_active_member())) with check(private.is_admin() or (user_id=auth.uid() and private.is_active_member()));
create policy questions_delete on public.questions for delete to authenticated using(private.is_admin() or (user_id=auth.uid() and private.is_active_member()));
create policy comments_read on public.comments for select to authenticated using(private.is_active_member());
create policy comments_create on public.comments for insert to authenticated with check(user_id=auth.uid() and private.is_active_member());
create policy comments_update on public.comments for update to authenticated using(user_id=auth.uid() and private.is_active_member()) with check(user_id=auth.uid() and private.is_active_member());
create policy comments_delete on public.comments for delete to authenticated using(private.is_admin() or (user_id=auth.uid() and private.is_active_member()));

-- Sem acesso anônimo, mesmo se permissões globais do projeto forem amplas.
revoke all on public.profiles,public.modules,public.lessons,public.lesson_progress,public.questions,public.comments from anon;
grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.modules,public.lessons,public.lesson_progress,public.questions,public.comments to authenticated;
grant all on public.profiles,public.modules,public.lessons,public.lesson_progress,public.questions,public.comments to service_role;
commit;