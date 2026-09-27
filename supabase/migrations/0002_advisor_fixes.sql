-- Wolody — Supabase 보안·성능 점검(advisor) 경고 정리
-- 0001_init.sql 다음에 실행하세요.

-- 트리거 함수가 호출한 사람의 search_path를 따르지 않도록 고정한다.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- RLS 정책의 auth.uid()를 (select auth.uid())로 감싸 행마다 다시 계산하지 않게 한다.
drop policy if exists "own rows select" on public.mood_entries;
create policy "own rows select" on public.mood_entries
  for select using ((select auth.uid()) = user_id);

drop policy if exists "own rows insert" on public.mood_entries;
create policy "own rows insert" on public.mood_entries
  for insert with check ((select auth.uid()) = user_id);

drop policy if exists "own rows update" on public.mood_entries;
create policy "own rows update" on public.mood_entries
  for update using ((select auth.uid()) = user_id);

drop policy if exists "own rows delete" on public.mood_entries;
create policy "own rows delete" on public.mood_entries
  for delete using ((select auth.uid()) = user_id);

drop policy if exists "own photos select" on storage.objects;
create policy "own photos select" on storage.objects
  for select using (
    bucket_id = 'mood-photos'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

drop policy if exists "own photos insert" on storage.objects;
create policy "own photos insert" on storage.objects
  for insert with check (
    bucket_id = 'mood-photos'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

drop policy if exists "own photos update" on storage.objects;
create policy "own photos update" on storage.objects
  for update using (
    bucket_id = 'mood-photos'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );

drop policy if exists "own photos delete" on storage.objects;
create policy "own photos delete" on storage.objects
  for delete using (
    bucket_id = 'mood-photos'
    and (select auth.uid())::text = (storage.foldername(name))[1]
  );
