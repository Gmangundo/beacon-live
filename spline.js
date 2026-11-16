// Paste your Spline public URLs (they end in .splinecode) between the quotes. Leave '' to keep the built-in 3D.
window.BEACON_SPLINE={home:'',winner:''};
(()=>{const c=navigator.connection||{},u=window.BEACON_SPLINE,
 ok=!c.saveData&&!/^(slow-2g|2g|3g)$/.test(c.effectiveType||'')&&(navigator.deviceMemory||4)>=4&&innerWidth>=700;
 if(!ok||!(u.home||u.winner))return;
 const s=document.createElement('script');s.type='module';s.src='https://cdn.jsdelivr.net/npm/@splinetool/viewer@1.10.64/build/spline-viewer.js';document.head.appendChild(s);
 if(u.home&&document.getElementById('hero')){const v=document.createElement('spline-viewer');v.setAttribute('url',u.home);v.setAttribute('events-target','global');v.setAttribute('loading-anim','true');
  v.style.cssText='position:fixed;inset:0;width:100%;height:100%;z-index:-1';
  v.addEventListener('load-complete',()=>{const h=document.getElementById('hero');if(h)h.style.display='none'});document.body.prepend(v)}})();
