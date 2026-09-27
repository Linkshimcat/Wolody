-- Wolody — Supabase 스키마
-- Supabase 대시보드 → SQL Editor에서 이 파일 전체를 실행하세요.

-- ---------------------------------------------------------------------------
-- 기분 기록 테이블
-- ---------------------------------------------------------------------------
create table if not exists public.mood_entries (
  id text primary key,            -- 앱에서 만드는 고유 id (마이크로초 타임스탬프)
  user_id uuid not null references auth.users (id) on delete cascade,
  date timestamptz not null default now(),
  emojis text[] not null default '{}',
  note text not null default '',
  image_file_name text,           -- 사진 파일명 (mood-photos 버킷의 {user_id}/{file})
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mood_entries_user_date_idx
  on public.mood_entries (user_id, date desc);

-- RLS: 자기 기록만 읽고/쓰고/지운다.
alter table public.mood_entries enable row level security;

drop policy if exists "own rows select" on public.mood_entries;
create policy "own rows select" on public.mood_entries
  for select using (auth.uid() = user_id);

drop policy if exists "own rows insert" on public.mood_entries;
create policy "own rows insert" on public.mood_entries
  for insert with check (auth.uid() = user_id);

drop policy if exists "own rows update" on public.mood_entries;
create policy "own rows update" on public.mood_entries
  for update using (auth.uid() = user_id);

drop policy if exists "own rows delete" on public.mood_entries;
create policy "own rows delete" on public.mood_entries
  for delete using (auth.uid() = user_id);

-- 수정 시각 자동 갱신
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_mood_entries_updated on public.mood_entries;
create trigger trg_mood_entries_updated
  before update on public.mood_entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 첨부 사진 저장소 버킷
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('mood-photos', 'mood-photos', false)
on conflict (id) do nothing;

-- 각 사용자는 자기 폴더({user_id}/...)의 객체만 다룰 수 있다.
drop policy if exists "own photos select" on storage.objects;
create policy "own photos select" on storage.objects
  for select using (
    bucket_id = 'mood-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "own photos insert" on storage.objects;
create policy "own photos insert" on storage.objects
  for insert with check (
    bucket_id = 'mood-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "own photos update" on storage.objects;
create policy "own photos update" on storage.objects
  for update using (
    bucket_id = 'mood-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "own photos delete" on storage.objects;
create policy "own photos delete" on storage.objects
  for delete using (
    bucket_id = 'mood-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );
