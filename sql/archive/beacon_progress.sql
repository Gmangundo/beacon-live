-- BEACON PROGRESS: XP, levels, streaks, badges, groups, season leaderboards, name filter. Run ONCE in Supabase SQL Editor. Safe to re-run.
create table if not exists public.profiles(user_id uuid primary key, display_name text not null default 'Player', xp int not null default 0, streak int not null default 0, best_streak int not null default 0, last_play date, games int not null default 0, badges text[] not null default '{}', show_global boolean not null default false, created_at timestamptz not null default now());
create table if not exists public.xp_events(user_id uuid not null, session_id uuid not null, xp int not null, rank int, created_at timestamptz not null default now(), primary key(user_id,session_id));
create table if not exists public.groups(id uuid primary key default gen_random_uuid(), code text unique not null, name text not null, owner uuid not null, season_days int not null default 30, season_start date not null default current_date, created_at timestamptz not null default now());
create table if not exists public.group_members(group_id uuid not null references public.groups on delete cascade, user_id uuid not null, primary key(group_id,user_id));
create table if not exists public.blocked_words(word text primary key);
insert into public.blocked_words values('fuck'),('shit'),('bitch'),('cunt'),('pussy'),('whore'),('slut'),('nazi') on conflict do nothing;  -- add more words (any language) here any time
alter table public.profiles enable row level security; alter table public.xp_events enable row level security; alter table public.groups enable row level security; alter table public.group_members enable row level security; alter table public.blocked_words enable row level security;

create or replace function public.is_clean(p text) returns boolean language sql stable security definer set search_path=public as $$
 select not exists(select 1 from public.blocked_words w where position(w.word in regexp_replace(translate(lower(coalesce(p,'')),'01345@$','oieasas'),'[^a-z]','','g'))>0)
$$;

create or replace function public.my_profile() returns jsonb language plpgsql security definer set search_path=public as $$
declare p public.profiles;
begin
 if auth.uid() is null then return null; end if;
 insert into public.profiles(user_id) values(auth.uid()) on conflict do nothing;
 select * into p from public.profiles where user_id=auth.uid();
 return to_jsonb(p)-'user_id';
end$$;

create or replace function public.set_profile(p_name text, p_global boolean) returns jsonb language plpgsql security definer set search_path=public as $$
declare n text:=trim(coalesce(p_name,''));
begin
 if auth.uid() is null then return jsonb_build_object('ok',false,'error','net'); end if;
 if length(n) not between 2 and 20 or n ~ '[<>&"]' or not public.is_clean(n) then return jsonb_build_object('ok',false,'error','bad_name'); end if;
 insert into public.profiles(user_id,display_name,show_global) values(auth.uid(),n,coalesce(p_global,false))
  on conflict(user_id) do update set display_name=excluded.display_name, show_global=excluded.show_global;
 return jsonb_build_object('ok',true);
end$$;

create or replace function public.award_session(p_session uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare x jsonb; rk int; sc int; gain int; p public.profiles; st int; lv int; cand text[]; nb text[]; today date:=current_date;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false); end if;
 if exists(select 1 from public.xp_events where user_id=auth.uid() and session_id=p_session) then return jsonb_build_object('ok',false,'error','already'); end if;
 select s.j into x from (select to_jsonb(t) j from public.get_leaderboard(p_session_id=>p_session, p_limit=>1000) t) s where (s.j->>'is_me')::boolean is true limit 1;
 if x is null then return jsonb_build_object('ok',false,'error','not_in_game'); end if;
 rk:=(x->>'rank')::int; sc:=coalesce((x->>'score')::int,0);
 gain:=50+least(greatest(sc,0)/20,300)+case rk when 1 then 100 when 2 then 60 when 3 then 40 else 0 end;
 insert into public.profiles(user_id) values(auth.uid()) on conflict do nothing;
 select * into p from public.profiles where user_id=auth.uid() for update;
 st:=case when p.last_play=today then p.streak when p.last_play=today-1 then p.streak+1 else 1 end;
 lv:=floor(sqrt((p.xp+gain)/100.0))::int+1;
 cand:=array_remove(array[case when p.games=0 then 'first_game' end, case when rk<=3 then 'podium' end, case when rk=1 then 'champion' end, case when st>=3 then 'on_fire' end, case when p.games+1>=5 then 'regular' end, case when lv>=5 then 'rising_star' end],null);
 nb:=array(select unnest(cand) except select unnest(p.badges));
 update public.profiles set xp=xp+gain, streak=st, best_streak=greatest(best_streak,st), last_play=today, games=games+1, badges=array(select distinct unnest(badges||cand)) where user_id=auth.uid();
 insert into public.xp_events(user_id,session_id,xp,rank) values(auth.uid(),p_session,gain,rk);
 return jsonb_build_object('ok',true,'xp',gain,'total',p.xp+gain,'level',lv,'streak',st,'rank',rk,'score',sc,'new_badges',to_jsonb(nb));
end$$;

create or replace function public.lb_global() returns jsonb language sql security definer set search_path=public as $$
 select coalesce(jsonb_agg(jsonb_build_object('name',n,'xp',x) order by x desc),'[]'::jsonb) from (
  select p.display_name n, sum(e.xp)::int x from public.xp_events e join public.profiles p on p.user_id=e.user_id
  where p.show_global and e.created_at>=now()-interval '30 days' group by p.user_id,p.display_name order by 2 desc limit 20) t
$$;

create or replace function public.create_group(p_name text, p_days int) returns jsonb language plpgsql security definer set search_path=public as $$
declare c text:=''; i int;
begin
 if not public.is_host() then return jsonb_build_object('ok',false,'error','not_host'); end if;
 if length(trim(coalesce(p_name,''))) not between 2 and 40 or p_days not between 1 and 365 then return jsonb_build_object('ok',false,'error','bad_input'); end if;
 loop
  c:=''; for i in 1..6 loop c:=c||substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789',1+floor(random()*31)::int,1); end loop;
  exit when not exists(select 1 from public.groups where code=c);
 end loop;
 insert into public.groups(code,name,owner,season_days) values(c,trim(p_name),auth.uid(),p_days);
 return jsonb_build_object('ok',true,'code',c);
end$$;

create or replace function public.join_group(p_code text) returns jsonb language plpgsql security definer set search_path=public as $$
declare g public.groups;
begin
 if auth.uid() is null then return jsonb_build_object('ok',false); end if;
 select * into g from public.groups where code=upper(trim(coalesce(p_code,'')));
 if g.id is null then return jsonb_build_object('ok',false,'error','no_group'); end if;
 insert into public.profiles(user_id) values(auth.uid()) on conflict do nothing;
 insert into public.group_members values(g.id,auth.uid()) on conflict do nothing;
 return jsonb_build_object('ok',true,'code',g.code,'name',g.name);
end$$;

create or replace function public.my_groups() returns jsonb language sql security definer set search_path=public as $$
 select coalesce(jsonb_agg(jsonb_build_object('code',g.code,'name',g.name) order by g.name),'[]'::jsonb)
 from public.groups g where g.owner=auth.uid() or exists(select 1 from public.group_members m where m.group_id=g.id and m.user_id=auth.uid())
$$;

create or replace function public.lb_group(p_code text) returns jsonb language plpgsql security definer set search_path=public as $$
declare g public.groups; st date; r jsonb;
begin
 select * into g from public.groups where code=upper(trim(coalesce(p_code,'')));
 if g.id is null then return jsonb_build_object('error','no_group'); end if;
 if not (g.owner=auth.uid() or exists(select 1 from public.group_members where group_id=g.id and user_id=auth.uid())) then return jsonb_build_object('error','not_member'); end if;
 st:=g.season_start+((current_date-g.season_start)/g.season_days)*g.season_days;
 select coalesce(jsonb_agg(jsonb_build_object('name',n,'xp',x) order by x desc),'[]'::jsonb) into r from (
  select p.display_name n, coalesce(sum(e.xp) filter (where e.created_at::date>=st),0)::int x
  from public.group_members m join public.profiles p on p.user_id=m.user_id left join public.xp_events e on e.user_id=m.user_id
  where m.group_id=g.id group by p.user_id,p.display_name) t;
 return jsonb_build_object('name',g.name,'days_left',(st+g.season_days)-current_date,'rows',r);
end$$;

revoke all on function public.is_clean(text),public.my_profile(),public.set_profile(text,boolean),public.award_session(uuid),public.lb_global(),public.create_group(text,int),public.join_group(text),public.my_groups(),public.lb_group(text) from public;
grant execute on function public.is_clean(text),public.my_profile(),public.set_profile(text,boolean),public.award_session(uuid),public.lb_global(),public.create_group(text,int),public.join_group(text),public.my_groups(),public.lb_group(text) to authenticated;
