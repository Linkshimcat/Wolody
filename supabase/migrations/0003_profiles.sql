-- Wolody — 계정별 프로필(닉네임·프로필 사진)
-- 사진 파일은 기존 mood-photos 버킷의 {user_id}/ 폴더에 함께 둔다(기존 정책으로 보호).

create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null,
  photo_file_name text,            -- mood-photos 버킷의 {user_id}/{file}
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "own profile select" on public.profiles;
create policy "own profile select" on public.profiles
  for select using ((select auth.uid()) = user_id);

drop policy if exists "own profile insert" on public.profiles;
create policy "own profile insert" on public.profiles
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists "own profile update" on public.profiles;
create policy "own profile update" on public.profiles
  for update using ((select auth.uid()) = user_id);

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();
