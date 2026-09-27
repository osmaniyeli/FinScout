/* FinScout website interactions (original). Uses GSAP + ScrollTrigger when available,
   and falls back to plain behaviour so every control keeps working without them. */
(function(){
  'use strict';
  var d=document, root=d.documentElement;
  root.classList.add('js');
  var reduce=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hasG=!!(window.gsap&&window.ScrollTrigger)&&!reduce;
  if(hasG) gsap.registerPlugin(ScrollTrigger);

  /* ---------- Header: theme follows the section underneath ---------- */
  var header=d.querySelector('.site-header');
  var themed=[].slice.call(d.querySelectorAll('[data-header-theme]'));
  function headerTheme(){
    if(!header) return;
    var y=header.getBoundingClientRect().top+26, t='dark';
    for(var i=0;i<themed.length;i++){var r=themed[i].getBoundingClientRect(); if(r.top<=y&&r.bottom>y){t=themed[i].getAttribute('data-header-theme');break;}}
    header.setAttribute('data-theme',t);
  }
  /* active nav item */
  var navLinks=[].slice.call(d.querySelectorAll('.nav a[href^="#"]'));
  function activeNav(){
    var cur=null;
    navLinks.forEach(function(a){var s=d.querySelector(a.getAttribute('href')); if(s&&s.getBoundingClientRect().top<innerHeight*0.4) cur=a;});
    navLinks.forEach(function(a){a.classList.toggle('is-active',a===cur);});
  }
  var ticking=false;
  function onScroll(){ if(ticking) return; ticking=true; requestAnimationFrame(function(){headerTheme();activeNav();ticking=false;}); }
  addEventListener('scroll',onScroll,{passive:true}); addEventListener('resize',onScroll); headerTheme();

  /* ---------- Language dropdown ---------- */
  d.querySelectorAll('.lang').forEach(function(l){
    var b=l.querySelector('.lang-btn');
    b.addEventListener('click',function(e){e.stopPropagation(); var o=l.classList.toggle('open'); b.setAttribute('aria-expanded',o);});
    d.addEventListener('click',function(e){ if(!l.contains(e.target)){l.classList.remove('open');b.setAttribute('aria-expanded','false');} });
    d.addEventListener('keydown',function(e){ if(e.key==='Escape'){l.classList.remove('open');b.setAttribute('aria-expanded','false');} });
  });

  /* ---------- Carousels ---------- */
  d.querySelectorAll('[data-carousel]').forEach(function(c){
    var tr=c.querySelector('.track'), prev=c.querySelector('[data-prev]'), next=c.querySelector('[data-next]');
    function step(){ var k=tr.children[0]; var g=parseFloat(getComputedStyle(tr).columnGap)||24; return k?k.getBoundingClientRect().width+g:320; }
    function upd(){ prev.disabled=tr.scrollLeft<4; next.disabled=tr.scrollLeft+tr.clientWidth>=tr.scrollWidth-4; }
    prev.addEventListener('click',function(){tr.scrollBy({left:-step(),behavior:'smooth'});});
    next.addEventListener('click',function(){tr.scrollBy({left:step(),behavior:'smooth'});});
    tr.addEventListener('scroll',upd,{passive:true}); addEventListener('resize',upd); upd();
  });

  /* ---------- Tabs ---------- */
  d.querySelectorAll('[data-tabs]').forEach(function(w){
    var tabs=[].slice.call(w.querySelectorAll('[role=tab]'));
    var imgs=[].slice.call(w.querySelectorAll('.tab-phone img'));
    var descs=[].slice.call(w.querySelectorAll('.tab-desc [data-i]'));
    function sel(i,focus){
      tabs.forEach(function(t,k){t.setAttribute('aria-selected',k===i);t.tabIndex=k===i?0:-1;});
      imgs.forEach(function(m,k){m.classList.toggle('on',k===i);});
      descs.forEach(function(p,k){p.hidden=k!==i;});
      if(focus) tabs[i].focus();
      tabs[i].scrollIntoView({block:'nearest',inline:'center',behavior:'smooth'});
    }
    tabs.forEach(function(t,i){
      t.addEventListener('click',function(){sel(i);});
      t.addEventListener('keydown',function(e){ if(e.key==='ArrowRight'){e.preventDefault();sel((i+1)%tabs.length,true);} if(e.key==='ArrowLeft'){e.preventDefault();sel((i-1+tabs.length)%tabs.length,true);} });
    });
  });

  /* ---------- FAQ accordion ---------- */
  d.querySelectorAll('.qa button').forEach(function(b){
    var a=d.getElementById(b.getAttribute('aria-controls'));
    b.addEventListener('click',function(){
      var open=b.getAttribute('aria-expanded')==='true';
      b.setAttribute('aria-expanded',!open);
      if(open){ a.style.height=a.scrollHeight+'px'; requestAnimationFrame(function(){a.style.height='0px';}); }
      else { a.style.height=a.scrollHeight+'px'; a.addEventListener('transitionend',function h(){ if(b.getAttribute('aria-expanded')==='true') a.style.height='auto'; a.removeEventListener('transitionend',h);}); }
    });
  });

  /* ---------- Pinned steppers ---------- */
  d.querySelectorAll('[data-stepper]').forEach(function(s){
    var stage=s.querySelector('.pin-stage');
    var dots=[].slice.call(s.querySelectorAll('.dots button'));
    var texts=[].slice.call(s.querySelectorAll('.step-text > div'));
    var vis=[].slice.call(s.querySelectorAll('[data-step]'));
    var n=dots.length, cur=-1, st=null, timer=null, userPicked=false;
    function show(i){
      if(i===cur) return; cur=i;
      dots.forEach(function(b,k){b.classList.toggle('on',k===i);b.setAttribute('aria-current',k===i?'step':'false');});
      texts.forEach(function(t,k){t.classList.toggle('on',k===i);});
      vis.forEach(function(v){v.classList.toggle('on',+v.getAttribute('data-step')===i);});
    }
    show(0);
    if(hasG){
      st=ScrollTrigger.create({trigger:stage,start:'top top',end:'+='+(n*innerHeight*0.7),pin:true,scrub:true,
        onUpdate:function(self){show(Math.min(n-1,Math.floor(self.progress*n*0.999)));}});
    }
    dots.forEach(function(b,i){
      b.addEventListener('click',function(){
        if(st){ var y=st.start+(st.end-st.start)*((i+0.5)/n); window.scrollTo({top:y,behavior:'smooth'}); }
        else { userPicked=true; clearInterval(timer); timer=null; show(i); }
      });
    });
    if(!hasG && !reduce){ /* no GSAP: auto-advance while visible, until the user picks a step */
      var io=new IntersectionObserver(function(e){ if(e[0].isIntersecting){ if(!timer&&!userPicked) timer=setInterval(function(){show((cur+1)%n);},3500);} else {clearInterval(timer);timer=null;} },{threshold:.4});
      io.observe(s);
    }
  });

  /* ---------- Word reveal ---------- */
  d.querySelectorAll('.reveal-words').forEach(function(el){
    var words=[];
    (function walk(node){
      [].slice.call(node.childNodes).forEach(function(c){
        if(c.nodeType===3){
          var frag=d.createDocumentFragment();
          c.textContent.split(/(\s+)/).forEach(function(p){ if(!p) return; if(/^\s+$/.test(p)){frag.appendChild(d.createTextNode(p));} else {var sp=d.createElement('span');sp.className='w';sp.textContent=p;frag.appendChild(sp);words.push(sp);} });
          node.replaceChild(frag,c);
        } else if(c.nodeType===1) walk(c);
      });
    })(el);
    if(hasG){
      ScrollTrigger.create({trigger:el,start:'top 80%',end:'bottom 45%',scrub:true,onUpdate:function(s){var k=Math.round(s.progress*words.length);words.forEach(function(w,i){w.classList.toggle('on',i<k);});}});
    } else words.forEach(function(w){w.classList.add('on');});
  });

  /* ---------- GSAP motion ---------- */
  if(hasG){
    gsap.utils.toArray('.fx').forEach(function(el){
      gsap.to(el,{opacity:1,y:0,duration:.9,ease:'power3.out',delay:+(el.getAttribute('data-delay')||0),scrollTrigger:{trigger:el,start:'top 88%',once:true}});
    });
    var hb=d.querySelector('.hero-bg');
    if(hb) gsap.to(hb,{scale:1.12,yPercent:6,ease:'none',scrollTrigger:{trigger:'.hero',start:'top top',end:'bottom top',scrub:true}});
    gsap.utils.toArray('.orb .glow').forEach(function(g){gsap.to(g,{rotate:360,duration:18,repeat:-1,ease:'none'});});
    gsap.utils.toArray('.orb').forEach(function(o){gsap.fromTo(o,{scale:.85},{scale:1,ease:'none',scrollTrigger:{trigger:o,start:'top bottom',end:'center center',scrub:true}});});
    gsap.utils.toArray('.bloom img').forEach(function(b){gsap.fromTo(b,{rotate:-12,scale:.9},{rotate:0,scale:1,ease:'none',scrollTrigger:{trigger:b,start:'top bottom',end:'center 45%',scrub:true}});});
    gsap.utils.toArray('.ocard').forEach(function(c,i){gsap.from(c,{opacity:0,scale:.92,duration:.8,delay:i*.08,ease:'power2.out',scrollTrigger:{trigger:c,start:'top 90%',once:true}});});
    gsap.utils.toArray('[data-count]').forEach(function(el){
      var end=parseFloat(el.getAttribute('data-count')), dec=+(el.getAttribute('data-dec')||0), pre=el.getAttribute('data-pre')||'', suf=el.getAttribute('data-suf')||'';
      var o={v:0}; var fmt=function(v){return pre+v.toLocaleString(root.lang==='en'?'en-US':'tr-TR',{minimumFractionDigits:dec,maximumFractionDigits:dec})+suf;};
      gsap.to(o,{v:end,duration:1.4,ease:'power2.out',scrollTrigger:{trigger:el,start:'top 90%',once:true},onUpdate:function(){el.textContent=fmt(o.v);},onComplete:function(){el.textContent=fmt(end);}});
    });
    addEventListener('load',function(){ScrollTrigger.refresh();});
  } else {
    d.querySelectorAll('.fx').forEach(function(el){el.style.opacity=1;el.style.transform='none';});
  }

  /* smooth anchor offset for fixed header */
  d.querySelectorAll('a[href^="#"]').forEach(function(a){
    a.addEventListener('click',function(e){
      var id=a.getAttribute('href'); if(id.length<2) return;
      var t=d.querySelector(id); if(!t) return;
      e.preventDefault();
      var y=t.getBoundingClientRect().top+scrollY-(id==='#icerik'?0:76);
      window.scrollTo({top:y,behavior:reduce?'auto':'smooth'});
      history.replaceState(null,'',id);
    });
  });
})();
