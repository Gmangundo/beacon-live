-- Run ONCE in Supabase > SQL Editor, after the earlier files. Adds double/triple point rounds.
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
