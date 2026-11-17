-- BEACON SETUP (Family Feud, security lockdown, emoji, double/triple points). Paste ALL into Supabase SQL Editor and Run. Safe to re-run any time.

-- Beacon Family Feud: run ONCE in Supabase > SQL Editor. Only adds new things; nothing existing is changed.
create table if not exists public.feud_games(
 id uuid primary key default gen_random_uuid(), question text not null default '', answer_count int not null default 0,
 board jsonb not null default '[]', strikes int not null default 0, status text not null default 'closed',
 buzzed_team text, buzzed_by text, red_code text not null unique, blue_code text not null unique,
 red_score int not null default 0, blue_score int not null default 0, active boolean not null default true,
 created_at timestamptz not null default now());
create table if not exists public.feud_secret(game_id uuid primary key references public.feud_games on delete cascade, answers jsonb not null);
create table if not exists public.feud_players(id uuid primary key default gen_random_uuid(), game_id uuid not null references public.feud_games on delete cascade,
 user_id uuid not null, team text not null, nickname text not null, emoji text not null, unique(game_id,user_id));
alter table public.feud_games enable row level security;
alter table public.feud_secret enable row level security;
alter table public.feud_players enable row level security;
drop policy if exists feud_games_read on public.feud_games; create policy feud_games_read on public.feud_games for select to authenticated using (true);
drop policy if exists feud_players_read on public.feud_players; create policy feud_players_read on public.feud_players for select to authenticated using (true);
drop policy if exists feud_secret_host on public.feud_secret; create policy feud_secret_host on public.feud_secret for select to authenticated using (public.is_host());
do $$ begin if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='feud_games') then alter publication supabase_realtime add table public.feud_games; end if; end $$;

create or replace function public.feud_create(p_question text, p_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare g public.feud_games; r text; b text;
begin
 if not public.is_host() then return jsonb_build_object('error','not_host'); end if;
 update public.feud_games set active=false where active;
 loop
  r:=lpad((floor(random()*900000)+100000)::int::text,6,'0'); b:=lpad((floor(random()*900000)+100000)::int::text,6,'0');
  exit when r<>b and not exists(select 1 from public.feud_games where red_code in(r,b) or blue_code in(r,b));
 end loop;
 insert into public.feud_games(question,answer_count,red_code,blue_code) values(left(p_question,200),jsonb_array_length(p_answers),r,b) returning * into g;
 insert into public.feud_secret values(g.id,p_answers);
 return to_jsonb(g);
end$$;

create or replace function public.feud_status(p_game uuid, p_status text) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() or p_status not in('open','closed') then return jsonb_build_object('ok',false); end if;
 update public.feud_games set status=p_status, buzzed_team=null, buzzed_by=null where id=p_game;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_strike(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() then return jsonb_build_object('ok',false); end if;
 update public.feud_games set strikes=strikes+1 where id=p_game;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_reveal(p_game uuid, p_index int, p_team text) returns jsonb language plpgsql security definer set search_path=public as $$
declare a jsonb; pts int;
begin
 if not public.is_host() then return jsonb_build_object('ok',false); end if;
 select answers->p_index into a from public.feud_secret where game_id=p_game;
 if a is null or exists(select 1 from public.feud_games where id=p_game and board @> jsonb_build_array(jsonb_build_object('i',p_index))) then return jsonb_build_object('ok',false); end if;
 pts:=coalesce((a->>'points')::int,0);
 update public.feud_games set board=board||jsonb_build_array(jsonb_build_object('i',p_index,'text',a->>'text','points',pts)),
  red_score=red_score+case when p_team='red' then pts else 0 end, blue_score=blue_score+case when p_team='blue' then pts else 0 end where id=p_game;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_join(p_code text, p_nick text, p_emoji text) returns jsonb language plpgsql security definer set search_path=public as $$
declare g public.feud_games; t text; n text:=trim(coalesce(p_nick,''));
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'error','net'); end if;
 if length(n) not between 2 and 20 then return jsonb_build_object('ok',false,'error','bad_nickname'); end if;
 if coalesce(length(p_emoji),0) not between 1 and 8 then return jsonb_build_object('ok',false,'error','bad_emoji'); end if;
 select * into g from public.feud_games where active and (red_code=trim(p_code) or blue_code=trim(p_code));
 if not found then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 t:=case when g.red_code=trim(p_code) then 'red' else 'blue' end;
 insert into public.feud_players(game_id,user_id,team,nickname,emoji) values(g.id,auth.uid(),t,n,p_emoji)
  on conflict(game_id,user_id) do update set team=excluded.team,nickname=excluded.nickname,emoji=excluded.emoji;
 return jsonb_build_object('ok',true,'game_id',g.id,'team',t,'nickname',n,'emoji',p_emoji);
end$$;

create or replace function public.feud_buzz(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare pl public.feud_players;
begin
 select * into pl from public.feud_players where game_id=p_game and user_id=auth.uid();
 if not found then return jsonb_build_object('ok',false,'error','not_player'); end if;
 update public.feud_games set status='buzzed', buzzed_team=pl.team, buzzed_by=pl.emoji||' '||pl.nickname where id=p_game and status='open';
 if not found then return jsonb_build_object('ok',false,'error','too_late'); end if;
 return jsonb_build_object('ok',true);
end$$;

revoke all on function public.feud_create(text,jsonb),public.feud_status(uuid,text),public.feud_strike(uuid),public.feud_reveal(uuid,int,text),public.feud_join(text,text,text),public.feud_buzz(uuid) from public;
grant execute on function public.feud_create(text,jsonb),public.feud_status(uuid,text),public.feud_strike(uuid),public.feud_reveal(uuid,int,text),public.feud_join(text,text,text),public.feud_buzz(uuid) to authenticated;


-- Run ONCE after beacon_feud.sql. Adds "next question" with scores kept across rounds.
create or replace function public.feud_next_round(p_game uuid, p_question text, p_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() then return jsonb_build_object('error','not_host'); end if;
 update public.feud_games set question=left(p_question,200),answer_count=jsonb_array_length(p_answers),board='[]',strikes=0,status='closed',buzzed_team=null,buzzed_by=null where id=p_game;
 insert into public.feud_secret values(p_game,p_answers) on conflict(game_id) do update set answers=excluded.answers;
 return jsonb_build_object('ok',true);
end$$;
revoke all on function public.feud_next_round(uuid,text,jsonb) from public;
grant execute on function public.feud_next_round(uuid,text,jsonb) to authenticated;


-- BEACON SECURITY LOCKDOWN. Run ONCE, after beacon_feud.sql and beacon_feud_update.sql.
-- Safe to re-run. Replaces the earlier emoji setup.

-- 1. Team codes become host-only (players can no longer read them)
create table if not exists public.feud_codes(game_id uuid primary key references public.feud_games on delete cascade, red_code text not null unique, blue_code text not null unique);
alter table public.feud_codes enable row level security;
drop policy if exists feud_codes_host on public.feud_codes;
create policy feud_codes_host on public.feud_codes for select to authenticated using (public.is_host());
do $$ begin
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='feud_games' and column_name='red_code') then
  insert into public.feud_codes select id,red_code,blue_code from public.feud_games on conflict do nothing;
  alter table public.feud_games drop column red_code, drop column blue_code;
 end if; end $$;
create unique index if not exists feud_players_name on public.feud_players(game_id, lower(nickname));

create or replace function public.feud_create(p_question text, p_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare g public.feud_games; r text; b text;
begin
 if not public.is_host() then return jsonb_build_object('error','not_host'); end if;
 if jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers) not between 2 and 10 then return jsonb_build_object('error','bad_answers'); end if;
 update public.feud_games set active=false where active;
 loop
  r:=lpad((floor(random()*900000)+100000)::int::text,6,'0'); b:=lpad((floor(random()*900000)+100000)::int::text,6,'0');
  exit when r<>b and not exists(select 1 from public.feud_codes where red_code in(r,b) or blue_code in(r,b));
 end loop;
 insert into public.feud_games(question,answer_count) values(left(p_question,200),jsonb_array_length(p_answers)) returning * into g;
 insert into public.feud_codes values(g.id,r,b);
 insert into public.feud_secret values(g.id,p_answers);
 return to_jsonb(g);
end$$;

create or replace function public.feud_get_codes(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare c public.feud_codes;
begin
 if not public.is_host() then return jsonb_build_object('error','not_host'); end if;
 select * into c from public.feud_codes where game_id=p_game;
 return jsonb_build_object('red',c.red_code,'blue',c.blue_code);
end$$;

create or replace function public.feud_join(p_code text, p_nick text, p_emoji text) returns jsonb language plpgsql security definer set search_path=public as $$
declare gid uuid; t text; ex text; n text:=trim(coalesce(p_nick,'')); c text:=trim(coalesce(p_code,''));
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'error','net'); end if;
 if length(n) not between 2 and 20 or n ~ '[<>&"]' then return jsonb_build_object('ok',false,'error','bad_nickname'); end if;
 if coalesce(length(p_emoji),0) not between 1 and 8 or p_emoji ~ '[A-Za-z0-9<>&" '']' then return jsonb_build_object('ok',false,'error','bad_emoji'); end if;
 select k.game_id, case when k.red_code=c then 'red' else 'blue' end into gid,t
  from public.feud_codes k join public.feud_games g on g.id=k.game_id where g.active and (k.red_code=c or k.blue_code=c);
 if gid is null then return jsonb_build_object('ok',false,'error','invalid_code'); end if;
 select team into ex from public.feud_players where game_id=gid and user_id=auth.uid();
 if ex is not null then
  t:=ex; update public.feud_players set nickname=n, emoji=p_emoji where game_id=gid and user_id=auth.uid();
 else
  insert into public.feud_players(game_id,user_id,team,nickname,emoji) values(gid,auth.uid(),t,n,p_emoji);
 end if;
 return jsonb_build_object('ok',true,'game_id',gid,'team',t,'nickname',n,'emoji',p_emoji);
exception when unique_violation then return jsonb_build_object('ok',false,'error','nickname_taken');
end$$;

-- 2. Emoji on the normal quiz: only the player who holds their own participant id can set it
drop function if exists public.set_emoji(uuid,text,text);
create table if not exists public.emoji_picks(participant_id uuid primary key, emoji text not null);
alter table public.emoji_picks enable row level security;  -- no policies: reachable only through the functions below
create or replace function public.set_emoji(p_participant uuid, p_emoji text) returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null or coalesce(length(p_emoji),0) not between 1 and 8 or p_emoji ~ '[A-Za-z0-9<>&" '']' then return; end if;
 if not exists(select 1 from public.participants where id=p_participant) then return; end if;
 insert into public.emoji_picks values(p_participant,p_emoji) on conflict(participant_id) do update set emoji=excluded.emoji;
end$$;
create or replace function public.get_emojis(p_session uuid) returns table(nickname text, emoji text) language sql security definer set search_path=public as $$
 select p.nickname, e.emoji from public.emoji_picks e join public.participants p on p.id=e.participant_id where p.session_id=p_session
$$;

revoke all on function public.feud_create(text,jsonb),public.feud_get_codes(uuid),public.feud_join(text,text,text),public.set_emoji(uuid,text),public.get_emojis(uuid) from public;
grant execute on function public.feud_create(text,jsonb),public.feud_get_codes(uuid),public.feud_join(text,text,text),public.set_emoji(uuid,text),public.get_emojis(uuid) to authenticated;

-- Double/triple point rounds (kept last so it overrides the earlier feud_reveal and feud_next_round)
alter table public.feud_games add column if not exists mult int not null default 1;

create or replace function public.feud_set_mult(p_game uuid, p_mult int) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() or p_mult not between 1 and 3 then return jsonb_build_object('ok',false); end if;
 update public.feud_games set mult=p_mult where id=p_game;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_reveal(p_game uuid, p_index int, p_team text) returns jsonb language plpgsql security definer set search_path=public as $$
declare a jsonb; pts int; m int;
begin
 if not public.is_host() or p_index < 0 then return jsonb_build_object('ok',false); end if;
 select answers->p_index into a from public.feud_secret where game_id=p_game;
 select mult into m from public.feud_games where id=p_game;
 if a is null or m is null or exists(select 1 from public.feud_games where id=p_game and board @> jsonb_build_array(jsonb_build_object('i',p_index))) then return jsonb_build_object('ok',false); end if;
 pts:=coalesce((a->>'points')::int,0)*m;
 update public.feud_games set board=board||jsonb_build_array(jsonb_build_object('i',p_index,'text',a->>'text','points',pts)),
  red_score=red_score+case when p_team='red' then pts else 0 end, blue_score=blue_score+case when p_team='blue' then pts else 0 end where id=p_game;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_next_round(p_game uuid, p_question text, p_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() then return jsonb_build_object('error','not_host'); end if;
 update public.feud_games set question=left(p_question,200),answer_count=jsonb_array_length(p_answers),board='[]',strikes=0,mult=1,status='closed',buzzed_team=null,buzzed_by=null where id=p_game;
 insert into public.feud_secret values(p_game,p_answers) on conflict(game_id) do update set answers=excluded.answers;
 return jsonb_build_object('ok',true);
end$$;

revoke all on function public.feud_set_mult(uuid,int) from public;
grant execute on function public.feud_set_mult(uuid,int) to authenticated;


-- =====================================================================
-- PHONE ANSWERS: players type answers on their phones, the server matches them to the hidden answers.
-- Round flow: one random player per team face off (only those two can buzz). The first to buzz types an answer.
-- If it is right, that team plays the round (its players take turns typing, no buzzing needed).
-- If it is wrong, the other face-off player gets a turn. If both miss, a new face-off starts.
-- 3 strikes = the other team gets ONE steal guess. Close-but-not-exact answers wait for the host to Accept or Reject.
-- Nothing here changes manual mode: a game stays in manual mode (the old buttons) until the host switches phone answers on.
-- =====================================================================
alter table public.feud_games
  add column if not exists mode text not null default 'manual',
  add column if not exists phase text not null default 'idle',
  add column if not exists ctrl_team text,
  add column if not exists bank int not null default 0,
  add column if not exists fo_red uuid,
  add column if not exists fo_blue uuid,
  add column if not exists fo_tries int not null default 0,
  add column if not exists fo_names text,
  add column if not exists turn_user uuid,
  add column if not exists turn_name text,
  add column if not exists has_pending boolean not null default false,
  add column if not exists last_try jsonb;
alter table public.feud_secret add column if not exists pending jsonb;  -- host-only (feud_secret is host-readable only)

-- ---- text helpers ----
create or replace function public.beacon_norm(t text) returns text language sql immutable as $$
 select regexp_replace(regexp_replace(trim(lower(coalesce(t,''))),'^(the|a|an) ',''),'[^[:alnum:]]','','g')
$$;

create or replace function public.beacon_lev(a text, b text) returns int language plpgsql immutable as $$
declare la int:=length(a); lb int:=length(b); prev int[]; cur int[]; i int; j int; c int;
begin
 if la=0 then return lb; end if;
 if lb=0 then return la; end if;
 prev:=array(select generate_series(0,lb));
 for i in 1..la loop
  cur:=array[i];
  for j in 1..lb loop
   c:=case when substr(a,i,1)=substr(b,j,1) then 0 else 1 end;
   cur[j+1]:=least(prev[j+1]+1,cur[j]+1,prev[j]+c);
  end loop;
  prev:=cur;
 end loop;
 return prev[lb+1];
end$$;

-- exact = same after cleaning (also plural/singular). close = a small typo or one contains the other. none = no match.
create or replace function public.feud_match(p_answers jsonb, p_board jsonb, p_text text) returns jsonb language plpgsql stable as $$
declare t text:=public.beacon_norm(p_text); i int; a text; d int; best int:=-1; bd int:=999; lim int;
begin
 if length(t)<1 then return jsonb_build_object('kind','none'); end if;
 for i in 0..jsonb_array_length(p_answers)-1 loop
  if p_board @> jsonb_build_array(jsonb_build_object('i',i)) then continue; end if;
  a:=public.beacon_norm(p_answers->i->>'text');
  if a='' then continue; end if;
  if a=t or a||'s'=t or a=t||'s' then d:=0;
  else
   lim:=case when length(a)>=9 then 2 when length(a)>=4 then 1 else 0 end;
   d:=public.beacon_lev(a,t);
   if d>lim then
    if length(t)>=4 and length(a)>=4 and (position(t in a)>0 or position(a in t)>0) then d:=1; else d:=999; end if;
   elsif d=0 then d:=0;
   end if;
  end if;
  if d<bd then bd:=d; best:=i; end if;
 end loop;
 if best<0 or bd>=999 then return jsonb_build_object('kind','none'); end if;
 return jsonb_build_object('kind',case when bd=0 then 'exact' else 'close' end,'i',best);
end$$;

-- ---- player helpers ----
create or replace function public.feud_pname(p_game uuid, p_user uuid) returns text language sql stable security definer set search_path=public as $$
 select emoji||' '||nickname from public.feud_players where game_id=p_game and user_id=p_user
$$;

create or replace function public.feud_next_player(p_game uuid, p_team text, p_after uuid) returns uuid language sql stable security definer set search_path=public as $$
 select coalesce(
  (select user_id from public.feud_players where game_id=p_game and team=p_team
    and id>(select id from public.feud_players where game_id=p_game and user_id=p_after) order by id limit 1),
  (select user_id from public.feud_players where game_id=p_game and team=p_team order by id limit 1))
$$;

create or replace function public.feud_pick_faceoff(p_game uuid) returns boolean language plpgsql security definer set search_path=public as $$
declare r uuid; b uuid;
begin
 select user_id into r from public.feud_players where game_id=p_game and team='red' order by random() limit 1;
 select user_id into b from public.feud_players where game_id=p_game and team='blue' order by random() limit 1;
 if r is null or b is null then return false; end if;
 update public.feud_games set phase='faceoff',fo_red=r,fo_blue=b,fo_tries=0,fo_names=public.feud_pname(p_game,r)||'  vs  '||public.feud_pname(p_game,b),
  status='open',buzzed_team=null,buzzed_by=null,turn_user=null,turn_name=null,has_pending=false where id=p_game;
 return true;
end$$;

-- ---- a right answer (exact match, or a close call the host accepted) ----
create or replace function public.feud_hit(p_game uuid, p_user uuid, p_idx int, p_typed text) returns void language plpgsql security definer set search_path=public as $$
declare G public.feud_games; pl public.feud_players; s jsonb; a jsonb; pts int; v_board jsonb; v_bank int; v_phase text; v_ctrl text; v_turn uuid; v_award text;
begin
 select * into G from public.feud_games where id=p_game for update;
 select answers into s from public.feud_secret where game_id=p_game;
 select * into pl from public.feud_players where game_id=p_game and user_id=p_user;
 a:=s->p_idx;
 if G.id is null or pl.id is null or a is null or G.board @> jsonb_build_array(jsonb_build_object('i',p_idx)) then return; end if;
 pts:=coalesce((a->>'points')::int,0)*G.mult;
 v_board:=G.board||jsonb_build_array(jsonb_build_object('i',p_idx,'text',a->>'text','points',pts));
 v_bank:=G.bank+pts; v_phase:=G.phase; v_ctrl:=G.ctrl_team; v_turn:=G.turn_user; v_award:=null;
 if G.phase='faceoff' then
  v_phase:='play'; v_ctrl:=pl.team; v_turn:=public.feud_next_player(p_game,pl.team,p_user);
 elsif G.phase='play' then
  v_turn:=public.feud_next_player(p_game,G.ctrl_team,p_user);
 elsif G.phase='steal' then
  v_phase:='over'; v_award:=pl.team; v_turn:=null;
 end if;
 if v_phase='play' and jsonb_array_length(v_board)>=G.answer_count then v_phase:='over'; v_award:=v_ctrl; v_turn:=null; end if;
 update public.feud_games set board=v_board,bank=v_bank,phase=v_phase,ctrl_team=v_ctrl,turn_user=v_turn,
  turn_name=case when v_turn is null then null else public.feud_pname(p_game,v_turn) end,
  strikes=case when G.phase='faceoff' then 0 else strikes end,
  status=case when v_phase='faceoff' then status else 'closed' end,
  buzzed_team=case when G.phase='faceoff' then pl.team else buzzed_team end,
  red_score=red_score+case when v_award='red' then v_bank else 0 end,
  blue_score=blue_score+case when v_award='blue' then v_bank else 0 end,
  has_pending=false,
  last_try=jsonb_build_object('name',public.feud_pname(p_game,p_user),'team',pl.team,'text',left(coalesce(p_typed,''),40),'res','hit','pts',pts)
 where id=p_game;
 update public.feud_secret set pending=null where game_id=p_game;
end$$;

-- ---- a wrong answer (or a close call the host rejected, or a skipped turn) ----
create or replace function public.feud_miss(p_game uuid, p_user uuid, p_typed text) returns void language plpgsql security definer set search_path=public as $$
declare G public.feud_games; pl public.feud_players; o uuid; oth text; v_str int; v_turn uuid; lt jsonb;
begin
 select * into G from public.feud_games where id=p_game for update;
 select * into pl from public.feud_players where game_id=p_game and user_id=p_user;
 if G.id is null or pl.id is null then return; end if;
 lt:=jsonb_build_object('name',public.feud_pname(p_game,p_user),'team',pl.team,'text',left(coalesce(p_typed,''),40),'res','miss');
 update public.feud_secret set pending=null where game_id=p_game;
 if G.phase='faceoff' then
  o:=case when pl.team='red' then G.fo_blue else G.fo_red end;
  if G.fo_tries=0 and o is not null then
   update public.feud_games set fo_tries=1,turn_user=o,turn_name=public.feud_pname(p_game,o),status='buzzed',
    buzzed_team=case when pl.team='red' then 'blue' else 'red' end,buzzed_by=public.feud_pname(p_game,o),has_pending=false,last_try=lt where id=p_game;
  else
   if not public.feud_pick_faceoff(p_game) then
    update public.feud_games set phase='idle',status='closed',turn_user=null,turn_name=null where id=p_game;
   end if;
   update public.feud_games set last_try=lt||jsonb_build_object('again',true),has_pending=false where id=p_game;
  end if;
 elsif G.phase='play' then
  v_str:=G.strikes+1;
  if v_str>=3 then
   oth:=case when G.ctrl_team='red' then 'blue' else 'red' end;
   select user_id into o from public.feud_players where game_id=p_game and team=oth order by random() limit 1;
   if o is null then
    update public.feud_games set strikes=v_str,phase='over',turn_user=null,turn_name=null,has_pending=false,last_try=lt,
     red_score=red_score+case when G.ctrl_team='red' then G.bank else 0 end,
     blue_score=blue_score+case when G.ctrl_team='blue' then G.bank else 0 end where id=p_game;
   else
    update public.feud_games set strikes=v_str,phase='steal',turn_user=o,turn_name=public.feud_pname(p_game,o),has_pending=false,last_try=lt where id=p_game;
   end if;
  else
   v_turn:=public.feud_next_player(p_game,G.ctrl_team,p_user);
   update public.feud_games set strikes=v_str,turn_user=v_turn,turn_name=public.feud_pname(p_game,v_turn),has_pending=false,last_try=lt where id=p_game;
  end if;
 elsif G.phase='steal' then
  update public.feud_games set phase='over',turn_user=null,turn_name=null,has_pending=false,last_try=lt||jsonb_build_object('steal_failed',true),
   red_score=red_score+case when G.ctrl_team='red' then G.bank else 0 end,
   blue_score=blue_score+case when G.ctrl_team='blue' then G.bank else 0 end where id=p_game;
 end if;
end$$;

-- ---- called by players ----
create or replace function public.feud_submit(p_game uuid, p_text text) returns jsonb language plpgsql security definer set search_path=public as $$
declare G public.feud_games; pl public.feud_players; s jsonb; m jsonb; t text:=left(trim(coalesce(p_text,'')),60);
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'error','net'); end if;
 select * into G from public.feud_games where id=p_game and active;
 if G.id is null or G.mode<>'auto' or G.phase not in('faceoff','play','steal') or G.turn_user is distinct from auth.uid() or G.has_pending
    or (G.phase='faceoff' and G.status<>'buzzed') then
  return jsonb_build_object('ok',false,'error','not_your_turn');
 end if;
 if length(t)<1 then return jsonb_build_object('ok',false,'error','empty'); end if;
 select * into pl from public.feud_players where game_id=p_game and user_id=auth.uid();
 select answers into s from public.feud_secret where game_id=p_game;
 m:=public.feud_match(s,G.board,t);
 if m->>'kind'='exact' then
  perform public.feud_hit(p_game,auth.uid(),(m->>'i')::int,t);
  return jsonb_build_object('ok',true,'res','hit');
 elsif m->>'kind'='close' then
  update public.feud_secret set pending=jsonb_build_object('user',auth.uid(),'idx',(m->>'i')::int,'text',t) where game_id=p_game;
  update public.feud_games set has_pending=true,
   last_try=jsonb_build_object('name',public.feud_pname(p_game,auth.uid()),'team',pl.team,'text',t,'res','close') where id=p_game;
  return jsonb_build_object('ok',true,'res','close');
 else
  perform public.feud_miss(p_game,auth.uid(),t);
  return jsonb_build_object('ok',true,'res','miss');
 end if;
end$$;

-- the face-off buzz: in phone-answers mode only the two face-off players can buzz (manual mode keeps the old behaviour)
create or replace function public.feud_buzz(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare pl public.feud_players; G public.feud_games;
begin
 select * into pl from public.feud_players where game_id=p_game and user_id=auth.uid();
 if not found then return jsonb_build_object('ok',false,'error','not_player'); end if;
 select * into G from public.feud_games where id=p_game;
 if G.mode='auto' then
  if G.phase<>'faceoff' or G.status<>'open' or (auth.uid() is distinct from G.fo_red and auth.uid() is distinct from G.fo_blue) then
   return jsonb_build_object('ok',false,'error','too_late');
  end if;
  update public.feud_games set status='buzzed',buzzed_team=pl.team,buzzed_by=pl.emoji||' '||pl.nickname,turn_user=auth.uid(),
   turn_name=pl.emoji||' '||pl.nickname,last_try=null where id=p_game and status='open';
  if not found then return jsonb_build_object('ok',false,'error','too_late'); end if;
  return jsonb_build_object('ok',true);
 end if;
 update public.feud_games set status='buzzed', buzzed_team=pl.team, buzzed_by=pl.emoji||' '||pl.nickname where id=p_game and status='open';
 if not found then return jsonb_build_object('ok',false,'error','too_late'); end if;
 return jsonb_build_object('ok',true);
end$$;

-- ---- called by the host ----
create or replace function public.feud_set_mode(p_game uuid, p_mode text) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() or p_mode not in('manual','auto') then return jsonb_build_object('ok',false); end if;
 update public.feud_games set mode=p_mode,
  phase=case when p_mode='manual' then 'idle' else phase end,
  status=case when p_mode='manual' then 'closed' else status end,
  turn_user=case when p_mode='manual' then null else turn_user end,
  turn_name=case when p_mode='manual' then null else turn_name end,has_pending=false where id=p_game;
 update public.feud_secret set pending=null where game_id=p_game;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_auto_start(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare ph text;
begin
 if not public.is_host() then return jsonb_build_object('ok',false,'error','not_host'); end if;
 select phase into ph from public.feud_games where id=p_game and active;
 if ph is null then return jsonb_build_object('ok',false,'error','no_game'); end if;
 if ph<>'idle' then return jsonb_build_object('ok',false,'error','already_started'); end if;
 update public.feud_games set mode='auto',bank=0,strikes=0,ctrl_team=null,last_try=null,has_pending=false where id=p_game;
 update public.feud_secret set pending=null where game_id=p_game;
 if not public.feud_pick_faceoff(p_game) then return jsonb_build_object('ok',false,'error','no_players'); end if;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_confirm(p_game uuid, p_accept boolean) returns jsonb language plpgsql security definer set search_path=public as $$
declare s jsonb;
begin
 if not public.is_host() then return jsonb_build_object('ok',false,'error','not_host'); end if;
 select pending into s from public.feud_secret where game_id=p_game;
 if s is null then return jsonb_build_object('ok',false,'error','nothing_pending'); end if;
 if p_accept then perform public.feud_hit(p_game,(s->>'user')::uuid,(s->>'idx')::int,s->>'text');
 else perform public.feud_miss(p_game,(s->>'user')::uuid,s->>'text'); end if;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_skip(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare G public.feud_games;
begin
 if not public.is_host() then return jsonb_build_object('ok',false,'error','not_host'); end if;
 select * into G from public.feud_games where id=p_game;
 if G.turn_user is not null and G.phase in('faceoff','play','steal') then perform public.feud_miss(p_game,G.turn_user,'(skipped)');
 elsif G.phase='faceoff' then perform public.feud_pick_faceoff(p_game); end if;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.feud_reveal_rest(p_game uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare s jsonb; b jsonb; i int;
begin
 if not public.is_host() then return jsonb_build_object('ok',false,'error','not_host'); end if;
 select answers into s from public.feud_secret where game_id=p_game;
 select board into b from public.feud_games where id=p_game;
 if s is null or b is null then return jsonb_build_object('ok',false); end if;
 for i in 0..jsonb_array_length(s)-1 loop
  if not b @> jsonb_build_array(jsonb_build_object('i',i)) then
   b:=b||jsonb_build_array(jsonb_build_object('i',i,'text',s->i->>'text','points',coalesce((s->i->>'points')::int,0),'rest',true));
  end if;
 end loop;
 update public.feud_games set board=b where id=p_game;
 return jsonb_build_object('ok',true);
end$$;

-- next question now also resets the phone-answers state (this replaces the earlier feud_next_round, so it stays last)
create or replace function public.feud_next_round(p_game uuid, p_question text, p_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_host() then return jsonb_build_object('error','not_host'); end if;
 update public.feud_games set question=left(p_question,200),answer_count=jsonb_array_length(p_answers),board='[]',strikes=0,mult=1,status='closed',
  buzzed_team=null,buzzed_by=null,phase='idle',ctrl_team=null,bank=0,fo_red=null,fo_blue=null,fo_tries=0,fo_names=null,
  turn_user=null,turn_name=null,has_pending=false,last_try=null where id=p_game;
 insert into public.feud_secret(game_id,answers,pending) values(p_game,p_answers,null) on conflict(game_id) do update set answers=excluded.answers,pending=null;
 return jsonb_build_object('ok',true);
end$$;

-- permissions: internal helpers are not callable from the browser; the rest are
revoke all on function public.beacon_norm(text),public.beacon_lev(text,text),public.feud_match(jsonb,jsonb,text),public.feud_pname(uuid,uuid),
 public.feud_next_player(uuid,text,uuid),public.feud_pick_faceoff(uuid),public.feud_hit(uuid,uuid,int,text),public.feud_miss(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.feud_submit(uuid,text),public.feud_buzz(uuid),public.feud_set_mode(uuid,text),public.feud_auto_start(uuid),public.feud_confirm(uuid,boolean),
 public.feud_skip(uuid),public.feud_reveal_rest(uuid),public.feud_next_round(uuid,text,jsonb) from public,anon;
grant execute on function public.feud_submit(uuid,text),public.feud_buzz(uuid),public.feud_set_mode(uuid,text),public.feud_auto_start(uuid),public.feud_confirm(uuid,boolean),
 public.feud_skip(uuid),public.feud_reveal_rest(uuid),public.feud_next_round(uuid,text,jsonb) to authenticated;
