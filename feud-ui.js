// Beacon Feud shared helpers: animated avatar characters.
window.AVATARS=['🦁','🐑','🦊','🐼','🐸','🐵','🐙','🦄','🐯','🐨','🐰','🐻','🕊️','🔥','👑'];
window.Av=(()=>{
 const seed=s=>[...String(s)].reduce((a,c)=>(a*31+c.codePointAt(0))>>>0,7);
 function html(e,o={}){const n=seed(e+(o.name||'')),hue=(seed(e)%12)*30;
  return `<span class="av ${o.cls||''}" style="--s:${typeof o.size==='string'?o.size:(o.size||48)+'px'};--bg:hsl(${hue} 55% 30%);--dl:-${(n%30)/10}s;--d:${(32+n%20)/10}s"><i>${esc(e)}</i></span>`}
 return{html}})();
