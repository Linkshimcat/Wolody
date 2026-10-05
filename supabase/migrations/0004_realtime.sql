-- Wolody — 기록 실시간 반영
-- 한 기기에서 기록을 추가·수정·삭제하면 같은 계정의 다른 기기 앱이 바로 받아
-- 동기화하도록 mood_entries 변경을 Realtime으로 내보낸다.
-- (추가·수정은 RLS로 내 행만 전달되고, 삭제는 id만 전달된다.)
alter publication supabase_realtime add table public.mood_entries;
