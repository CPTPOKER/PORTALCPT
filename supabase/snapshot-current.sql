-- PORTALCPT — snapshot complementar do Supabase (2026-10-06)
-- Base: supabase/schema.sql do commit 6bdb8c0. Sem secrets/dados/Auth.
create schema if not exists private;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.topics(id uuid primary key default gen_random_uuid(),module_id uuid not null references public.modules(id) on delete cascade,title text not null check(length(trim(title)) between 1 and 160),description text,position integer not null default 1 check(position between 1 and 999),created_at timestamptz not null default now());
create index if not exists topics_module_position_idx on public.topics(module_id,position);
alter table public.topics enable row level security;
grant select,insert,update,delete on public.topics to authenticated;
create policy topics_read on public.topics for select to authenticated using(private.is_active_member());
create policy topics_insert on public.topics for insert to authenticated with check(private.is_admin());
create policy topics_update on public.topics for update to authenticated using(private.is_admin()) with check(private.is_admin());
create policy topics_delete on public.topics for delete to authenticated using(private.is_admin());
alter table public.lessons add column if not exists topic_id uuid references public.topics(id) on delete set null;
create index if not exists lessons_topic_idx on public.lessons(topic_id);

alter table public.comments add column if not exists lesson_id uuid references public.lessons(id) on delete cascade;
alter table public.comments alter column question_id drop not null;
alter table public.comments add constraint comments_parent_check check((lesson_id is not null and question_id is null) or (lesson_id is null and question_id is not null));
create index if not exists comments_lesson_idx on public.comments(lesson_id,created_at);

alter table public.questions alter column video_url drop not null;
alter table public.questions add column if not exists image_path text;

create table if not exists public.question_attachments(id uuid primary key default gen_random_uuid(),question_id uuid not null references public.questions(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,storage_path text not null unique,position integer not null default 1 check(position between 1 and 20),created_at timestamptz not null default now());
create index if not exists question_attachments_question_idx on public.question_attachments(question_id,position);
alter table public.question_attachments enable row level security;
grant select,insert,update,delete on public.question_attachments to authenticated;
create policy question_attachments_read on public.question_attachments for select to authenticated using(private.is_active_member());
create policy question_attachments_insert on public.question_attachments for insert to authenticated with check(user_id=(select auth.uid()) and private.is_active_member());
create policy question_attachments_delete on public.question_attachments for delete to authenticated using((user_id=(select auth.uid()) and private.is_active_member()) or private.is_admin());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('question-images','question-images',false,10485760,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy question_images_read_active on storage.objects for select to authenticated using(bucket_id='question-images' and (select private.is_active_member()));
create policy question_images_insert_own on storage.objects for insert to authenticated with check(bucket_id='question-images' and (storage.foldername(name))[1]=(select auth.uid())::text and (select private.is_active_member()));
create policy question_images_delete_own_or_admin on storage.objects for delete to authenticated using(bucket_id='question-images' and ((storage.foldername(name))[1]=(select auth.uid())::text or (select private.is_admin())));

create table if not exists private.content_passwords(content_type text not null check(content_type in('module','topic')),content_id uuid not null,password_hash text not null,updated_at timestamptz not null default now(),primary key(content_type,content_id));
revoke all on private.content_passwords from public,anon,authenticated;
create or replace function public.content_lock_status(p_type text,p_id uuid) returns boolean language plpgsql security definer set search_path='' as $$ begin if not private.is_active_member() then raise exception 'Unauthorized'; end if; return exists(select 1 from private.content_passwords where content_type=p_type and content_id=p_id); end; $$;
create or replace function public.verify_content_password(p_type text,p_id uuid,p_password text) returns boolean language plpgsql security definer set search_path='' as $$ declare h text; begin if not private.is_active_member() then raise exception 'Unauthorized'; end if; select password_hash into h from private.content_passwords where content_type=p_type and content_id=p_id; if h is null then return true; end if; return h=extensions.crypt(p_password,h); end; $$;
create or replace function public.set_content_password(p_type text,p_id uuid,p_password text) returns void language plpgsql security definer set search_path='' as $$ begin if not private.is_admin() then raise exception 'Admin only'; end if; if p_password is null or length(p_password)<4 then raise exception 'Password must have at least 4 characters'; end if; insert into private.content_passwords values(p_type,p_id,extensions.crypt(p_password,extensions.gen_salt('bf')),now()) on conflict(content_type,content_id) do update set password_hash=excluded.password_hash,updated_at=now(); end; $$;
create or replace function public.remove_content_password(p_type text,p_id uuid) returns void language plpgsql security definer set search_path='' as $$ begin if not private.is_admin() then raise exception 'Admin only'; end if; delete from private.content_passwords where content_type=p_type and content_id=p_id; end; $$;
revoke all on function public.content_lock_status(text,uuid),public.verify_content_password(text,uuid,text),public.set_content_password(text,uuid,text),public.remove_content_password(text,uuid) from public,anon;
grant execute on function public.content_lock_status(text,uuid),public.verify_content_password(text,uuid,text),public.set_content_password(text,uuid,text),public.remove_content_password(text,uuid) to authenticated;

create or replace function public.guard_profile_update() returns trigger language plpgsql set search_path='' as $$ begin if current_user='service_role' then return new; end if; if (select auth.uid()) is not null and not private.is_admin() then if new.id is distinct from old.id or new.role is distinct from old.role or new.active is distinct from old.active or new.email is distinct from old.email or new.created_at is distinct from old.created_at then raise exception 'Access fields are admin-only'; end if; end if; return new; end; $$;
