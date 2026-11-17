// Beacon shared helpers: animated avatar characters, unlock levels and the character picker.
window.AVATARS=['🦁','🐑','🦊','🐼','🐸','🐵','🐰','🕊️','🐙','🔥','🐨','🐻','🐯','🦄','👑','🐲','🦅','🐺'];
window.AVATAR_LV={'🐙':2,'🔥':2,'🐨':3,'🐻':3,'🐯':4,'🦄':4,'👑':5,'🐲':5,'🦅':7,'🐺':10};  // everything else is free at level 1
window.levelOf=xp=>Math.floor(Math.sqrt((xp||0)/100))+1;
window.Av=(()=>{
 const seed=s=>[...String(s)].reduce((a,c)=>(a*31+c.codePointAt(0))>>>0,7);
 function html(e,o={}){const n=seed(e+(o.name||'')),hue=(seed(e)%12)*30;
  return `<span class="pav ${o.cls||''}" style="--s:${typeof o.size==='string'?o.size:(o.size||48)+'px'};--bg:hsl(${hue} 55% 30%);--dl:-${(n%30)/10}s;--d:${(32+n%20)/10}s"><i>${esc(e)}</i></span>`}
 // level of the signed-in player (1 for brand-new players)
 async function level(){try{const s=await sb.auth.getSession();if(!s.data.session)return 1;const{data}=await sb.rpc('my_profile');return data?levelOf(data.xp):1}catch(_){return 1}}
 // character picker: locked characters show the level they unlock at
 function picker(box,note,o){let cur=o.cur,lv=o.level||1;
  const draw=()=>{box.innerHTML=AVATARS.map(e=>{const need=AVATAR_LV[e]||1,lock=need>lv;return`<button type="button" data-e="${e}" class="${e===cur?'on':''}${lock?' lock':''}" aria-label="Character ${e}${lock?', unlocks at level '+need:''}">${html(e,{size:52})}${lock?`<span class="lk">Level ${need}</span>`:''}</button>`}).join('')};
  box.onclick=ev=>{const b=ev.target.closest('button');if(!b)return;const e=b.dataset.e,need=AVATAR_LV[e]||1;
   if(need>lv){if(note)note.textContent='Reach level '+need+' to unlock this character. Play games to earn XP!';return}
   cur=e;if(note)note.textContent='';o.onPick(e);draw()};
  draw();return{set level(v){lv=v;if(AVATAR_LV[cur]>lv){cur=AVATARS[0];o.onPick(cur)}draw()}}}
 return{html,level,picker}})();
