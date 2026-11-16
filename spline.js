// Beacon 3D scenes. Paste a Spline link between the quotes. Either kind works:
//   - a share link:   https://my.spline.design/....        (shown as a background, no clicks needed)
//   - a public file:  https://prod.spline.design/.../scene.splinecode   (interactive viewer)
//   all:    full-screen background on EVERY page (Quiz, Feud, Profile, Host, Settings, Studies)
//   home:   optional different scene just for the home page (leave '' to reuse "all")
//   winner: optional .splinecode scene behind the winner / celebration screen
// Leave all three '' to keep the built-in 3D. Only used on capable devices (wide screen, enough memory, good connection).
window.BEACON_SPLINE={all:'https://my.spline.design/lightningbulb-tE3BoDXZiPzLCyl3ViT9B5SB/',home:'',winner:''};
(()=>{const c=navigator.connection||{},u=window.BEACON_SPLINE,hero=document.getElementById('hero'),
 bg=hero?(u.home||u.all):(u.all||u.home),share=/^https?:\/\/my\.spline\.design\//.test(bg||''),
 ok=!c.saveData&&!/^(slow-2g|2g|3g)$/.test(c.effectiveType||'')&&(navigator.deviceMemory||4)>=4&&innerWidth>=700;
 if(!ok||!(bg||u.winner))return;
 window.BEACON_SPLINE_BG=!!bg; // tells bg3d.js not to draw the built-in 3D underneath
 if(u.winner||(bg&&!share)){const s=document.createElement('script');s.type='module';s.src='https://cdn.jsdelivr.net/npm/@splinetool/viewer@1.10.64/build/spline-viewer.js';document.head.appendChild(s)}
 if(!bg||!document.body)return;
 const fade='position:fixed;inset:0;width:100%;height:100%;z-index:-2;opacity:0;transition:opacity .8s;',shown=()=>{v.style.opacity='1';if(hero)hero.style.display='none'};
 let v;
 if(share){v=document.createElement('iframe');v.src=bg;v.setAttribute('aria-hidden','true');v.setAttribute('tabindex','-1');v.style.cssText=fade+'border:0;pointer-events:none';v.addEventListener('load',shown)}
 else{v=document.createElement('spline-viewer');v.setAttribute('url',bg);v.setAttribute('events-target','global');v.setAttribute('loading-anim','true');v.style.cssText=fade;v.addEventListener('load-complete',shown)}
 // soft dark scrim keeps text readable on top of any scene
 const m=document.createElement('div');m.setAttribute('aria-hidden','true');
 m.style.cssText='position:fixed;inset:0;z-index:-1;pointer-events:none;background:linear-gradient(180deg,rgba(7,10,20,.55),rgba(7,10,20,.2) 45%,rgba(7,10,20,.65))';
 document.body.prepend(m);document.body.prepend(v)})();
