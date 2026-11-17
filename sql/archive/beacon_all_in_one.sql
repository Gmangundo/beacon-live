-- BEACON: ALL-IN-ONE SETUP. Paste ALL of this into Supabase SQL Editor and click Run once. Safe to run again.

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
drop table if exists public.emoji_picks;
create table public.emoji_picks(participant_id uuid primary key, emoji text not null);
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
