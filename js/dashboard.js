// js/dashboard.js
var AGENTS=[{name:'warbleur',role:'the vanguard'},{name:'volt',role:'the reactor'},{name:'cypher',role:'the builder'},{name:'aster',role:'the wildcard'},{name:'ion',role:'in orbit'},{name:'echo',role:'in orbit'}];
function esc(v){return (v==null?'':String(v)).replace(/[<>&]/g,function(c){return {'<':'&lt;','>':'&gt;','&':'&amp;'}[c];});}
function ago(iso){if(!iso)return '';var d=new Date(iso);var s=Math.floor((Date.now()-d.getTime())/1000);if(s<60)return s+'s ago';if(s<3600)return Math.floor(s/60)+'m ago';if(s<86400)return Math.floor(s/3600)+'h ago';return Math.floor(s/86400)+'d ago';}
function pill(s){s=(s||'').toLowerCase();if(s.indexOf('complete')>-1)return '<span class="pill complete">complete</span>';if(s.indexOf('error')>-1||s.indexOf('invalid')>-1)return '<span class="pill error">error</span>';return '<span class="pill pending">pending</span>';}
function num(v){var n=parseFloat(v);return isNaN(n)?null:n;}
function avatarFor(desc){desc=(desc||'').toLowerCase();var hit=AGENTS.find(function(a){return desc.indexOf(a.name)>-1;});return hit?hit.name:'warbleur';}
function responsiveHero(){var img=document.getElementById('hero-img');if(!img)return;var w=window.innerWidth;if(w<=560)img.src='images/hero-mobile.png';else if(w<=900)img.src='images/hero-tablet.png';else img.src='images/hero-desktop.png';}
function renderAgents(){var el=document.getElementById('agents');if(!el)return;el.innerHTML=AGENTS.map(function(a){return '<div class="agent"><img src="images/'+a.name+'-avatar.png" alt="'+a.name+'" onerror="this.style.opacity=0.25" /><span class="status-dot"></span><span class="tip"><b>'+a.name+'</b> &middot; <span>'+a.role+'</span></span></div>';}).join('');}

function bestScore(subs){var b=null;subs.forEach(function(s){var n=num(s.publicScore);if(n!==null&&(b===null||n>b))b=n;});return b;}

var LAST_DATA=null;

function renderShip(data){
  var subs=data.submissions||[];
  var latest=subs[0]||{};
  var el=document.getElementById('panel-ship');
  var rank=data.rank||null; // injected from rank.js snapshot
  // headline live rating: prefer the rank snapshot score (settled ladder rating), else best submission
  var liveRating=rank&&rank.found&&rank.score?num(rank.score):null;
  var best=bestScore(subs);
  if(liveRating===null)liveRating=best;

  // FLAGSHIP = newest submission (subs[0]), even while pending
  var flag=latest;
  var flagshipDesc=flag.description||'the burroship';
  var burro=avatarFor(flagshipDesc);
  var flagStatus=(flag.status||'').replace('SubmissionStatus.','').toLowerCase();
  var isPending=flagStatus.indexOf('pending')>-1||flagStatus.indexOf('running')>-1;
  var counts=data.episode_counts||{};
  var gamesPlayed=flag.ref&&counts[flag.ref]!=null?counts[flag.ref]:null;
  var flagScore=num(flag.publicScore);

  // sorted unique submission scores, high to low
  var scores=subs.map(function(s){return num(s.publicScore);}).filter(function(n){return n!==null;}).sort(function(a,b){return b-a;});
  var baselineCount=scores.filter(function(n){return n===600;}).length;

  // honest performance read for the flagship, only from real data
  // compare flagship rating against the fleet's other settled ratings (exclude baseline 600s)
  var settled=subs.filter(function(s){var n=num(s.publicScore);return n!==null&&n!==600&&s.ref!==flag.ref;}).map(function(s){return num(s.publicScore);});
  var fleetAvg=settled.length?settled.reduce(function(a,b){return a+b;},0)/settled.length:null;
  var perf=null; // {cls,label}
  if(flagScore!==null&&flagScore!==600){
    if(fleetAvg!==null){
      var diff=flagScore-fleetAvg;
      if(diff>=8)perf={cls:'good',label:'above fleet avg'};
      else if(diff<=-8)perf={cls:'bad',label:'below fleet avg'};
      else perf={cls:'flat',label:'near fleet avg'};
    }
    if(flagScore<600&&(!perf||perf.cls!=='good'))perf=perf||{cls:'bad',label:'below baseline'};
  }

  var html='';
  html+='<div class="flagship" data-deployed="'+esc(flag.date||'')+'">';
  html+='<div class="flagship-top">';
  html+='<div class="pulse'+(isPending?' booting':'')+'"><span class="dot"></span> '+(isPending?'deploying to the ladder':'live on the ladder')+'</div>';
  html+='<div class="flag-clock" id="flag-clock"></div>';
  html+='</div>';
  html+='<div class="fleet-burro" style="margin-top:18px"><img src="images/'+burro+'-avatar.png" onerror="this.style.opacity=0.25" alt="'+burro+'" /><div class="who"><div class="nm">'+esc(burro)+'</div><div class="rl">flagship commander</div></div></div>';
  html+='<div class="flag-desc">'+esc(flagshipDesc)+'</div>';
  html+='<div class="flag-stats">';
  html+='<div class="fs"><span class="fs-k">status</span><span class="fs-v '+(isPending?'warn':'on')+'">'+(flagStatus||'\u2014')+'</span></div>';
  html+='<div class="fs"><span class="fs-k">deployed</span><span class="fs-v">'+(flag.date?ago(flag.date):'\u2014')+'</span></div>';
  html+='<div class="fs"><span class="fs-k">rating</span><span class="fs-v">'+(flagScore!==null?flagScore:'pending')+(perf?' <span class="perf '+perf.cls+'">'+(perf.cls==='good'?'\u25b2':perf.cls==='bad'?'\u25bc':'\u2192')+'</span>':'')+'</span>'+(perf?'<span class="fs-note '+perf.cls+'">'+perf.label+'</span>':'')+'</div>';
  html+='<div class="fs"><span class="fs-k">games played</span><span class="fs-v">'+(gamesPlayed!=null?gamesPlayed:'\u2014')+'</span></div>';
  html+='</div>';
  html+='</div>';

  html+='<div class="grid">';

  // RANK card
  html+='<div class="stat rank-card"><div class="label">Rank <span class="rank-refresh" id="rank-refresh" style="display:none"><span class="mini-spin"></span> refreshing</span></div>';
  if(rank&&rank.found){
    html+='<div class="rank-head"><span class="value heat">#'+rank.rank+'</span>'+movementArrow(rank.movement)+'</div>';
    html+='<div class="meta">of '+(rank.total_scanned||'\u2014')+' teams'+(rank.best_rank&&rank.best_rank<rank.rank?' \u00b7 best #'+rank.best_rank:'')+'</div>';
    html+=neighborStack(rank);
  }else{
    html+='<div class="rank-head"><span class="value heat scanning">scanning</span><span class="mini-spin"></span></div>';
    html+='<div class="meta">reading the live ladder, this takes a moment</div>';
  }
  html+='</div>';

  // RATING card (live)
  html+='<div class="stat"><div class="label">Live Rating</div>';
  html+='<div class="rank-head"><span class="value win">'+(liveRating!==null?liveRating:'\u2014')+'</span><span class="live-dot" title="pulled live"></span></div>';
  html+='<div class="meta">skill rating \u00b7 600 baseline</div>';
  if(scores.length>1){
    html+='<div class="mini-scores">'+scores.slice(0,5).map(function(n){return '<span'+(n===liveRating?' class="hot"':'')+'>'+n+'</span>';}).join('')+'</div>';
  }
  html+='</div>';

  // SUBMISSIONS card
  html+='<div class="stat"><div class="label">Submissions</div><div class="value">'+subs.length+'</div>';
  html+='<div class="meta">'+baselineCount+' at baseline 600 \u00b7 '+(latest.date?ago(latest.date):'\u2014')+'</div></div>';

  // LATEST card
  html+='<div class="stat"><div class="label">Latest</div><div class="value" style="font-size:24px">'+(latest.status||'\u2014').replace('SubmissionStatus.','').toLowerCase()+'</div>';
  html+='<div class="meta">'+esc((latest.description||'').slice(0,28))+'</div></div>';

  html+='</div>';
  el.innerHTML=html;
}

function movementArrow(m){
  if(m==null||m===0)return '<span class="move flat" title="no change since last sync">\u2014</span>';
  if(m>0)return '<span class="move up" title="climbed '+m+' since last sync">\u25b2 '+m+'</span>';
  return '<span class="move down" title="dropped '+Math.abs(m)+' since last sync">\u25bc '+Math.abs(m)+'</span>';
}

function neighborStack(rank){
  var above=(rank.neighbors_above||[]);
  var below=(rank.neighbors_below||[]);
  if(!above.length&&!below.length)return '';
  var h='<div class="neighbors">';
  above.forEach(function(e){h+=neighborRow(e,false);});
  h+=neighborRow({rank:rank.rank,name:'theburroship',score:rank.score},true);
  below.forEach(function(e){h+=neighborRow(e,false);});
  h+='</div>';
  return h;
}
function neighborRow(e,isMe){
  var href=isMe?'https://www.kaggle.com/theburroship':'https://www.kaggle.com/competitions/orbit-wars/leaderboard';
  return '<a class="nb'+(isMe?' me':'')+'" href="'+href+'" target="_blank" rel="noopener"><span class="nb-rank">#'+e.rank+'</span><span class="nb-name">'+esc((e.name||'').slice(0,18))+'</span><span class="nb-score">'+esc(e.score)+'</span></a>';
}

function renderBattles(data){
  var subs=(data.submissions||[]).filter(function(s){return num(s.publicScore)!==null;}).slice().reverse();
  var el=document.getElementById('panel-battles');
  var html='';

  // Featured replay player
  var eps=data.episodes||[];
  var featured=eps.find(function(e){return e.replayable;})||eps[0];
  html+='<div class="replay-feature">';
  html+='<div class="rf-head"><div class="rf-title"><span class="live"></span> game replay</div></div>';
  html+='<div class="rf-desc">Watch a real match the burroship played on Kaggle. Planets orbit the sun, fleets fly between them, ship counts update each turn. Pick an episode below to load it.</div>';
  if(featured){
    html+='<div class="rf-actions"><button class="btn-primary" id="open-featured" data-ep="'+esc(featured.id)+'" data-me="'+(featured.meIndex!=null?featured.meIndex:0)+'">&#9654;&nbsp; Watch latest game</button></div>';
  }
  html+='</div>';

  if(!subs.length){html+='<div class="empty">Battle data syncs once games complete.</div>';el.innerHTML=html;wireBattles();return;}
  var max=Math.max.apply(null,subs.map(function(s){return num(s.publicScore);}));
  var min=Math.min.apply(null,subs.map(function(s){return num(s.publicScore);}));
  var span=Math.max(1,max-min);
  html+='<div class="subhead">Score Progression</div><ul class="prog">';
  subs.forEach(function(s){var n=num(s.publicScore);var pct=20+((n-min)/span)*80;html+='<li><div class="plabel">'+esc((s.description||'').slice(0,22))+'</div><div class="bar"><span style="width:'+pct+'%"></span></div><div class="pscore">'+n+'</div></li>';});
  html+='</ul>';

  html+='<div class="subhead" style="margin-top:32px">Recent Episodes</div>';
  if(!eps.length){html+='<div class="empty">Episode sync pending. Each submission triggers validation games on Kaggle.</div>';}
  else{
    html+='<table><thead><tr><th>Episode</th><th>Status</th><th>When</th><th></th></tr></thead><tbody>';
    eps.forEach(function(e){
      var clk=e.replayable!==false;
      html+='<tr'+(clk?' class="clickable ep-row" data-ep="'+esc(e.id)+'" data-me="'+(e.meIndex!=null?e.meIndex:0)+'"':'')+'>';
      html+='<td>'+esc(e.id)+'</td><td>'+pill(e.state)+'</td><td>'+esc(ago(e.endTime||e.createTime))+'</td>';
      html+='<td>'+(clk?'<span class="watch">watch &#9654;</span>':'')+'</td></tr>';
    });
    html+='</tbody></table>';
  }
  el.innerHTML=html;
  wireBattles();
}

function wireBattles(){
  var feat=document.getElementById('open-featured');
  if(feat)feat.onclick=function(){openReplay(feat.getAttribute('data-ep'),parseInt(feat.getAttribute('data-me'),10)||0);};
  document.querySelectorAll('.ep-row').forEach(function(row){
    row.onclick=function(){openReplay(row.getAttribute('data-ep'),parseInt(row.getAttribute('data-me'),10)||0);};
  });
}

var REPLAY_CACHE={};
async function openReplay(epId,meIndex){
  var modal=document.getElementById('replay-modal');
  var statusEl=document.getElementById('replay-loading');
  var headTitle=document.getElementById('replay-mh-title');
  var headSub=document.getElementById('replay-mh-sub');
  if(!modal)return;
  modal.classList.add('open');
  document.body.style.overflow='hidden';
  if(headTitle)headTitle.textContent='episode '+epId;
  if(headSub)headSub.textContent='loading replay from kaggle';
  if(statusEl){statusEl.style.display='flex';statusEl.innerHTML='<div class="spinner"></div><div>pulling 500 turns of real game data<br>this can take a few seconds</div>';}
  var resultEl=document.getElementById('replay-result');if(resultEl)resultEl.style.display='none';
  try{
    var raw=REPLAY_CACHE[epId];
    if(!raw){
      var res=await fetch('/.netlify/functions/replay?id='+encodeURIComponent(epId),{cache:'no-store'});
      if(!res.ok)throw new Error('replay fetch '+res.status);
      raw=await res.json();
      if(raw.error)throw new Error(raw.error);
      REPLAY_CACHE[epId]=raw;
    }
    if(statusEl)statusEl.style.display='none';
    if(headSub)headSub.textContent=(raw.steps?raw.steps.length:0)+' turns';
    window.OrbitReplay.load(raw,meIndex);
  }catch(e){
    if(statusEl){statusEl.style.display='flex';statusEl.innerHTML='<div>could not load this replay<br><span style="color:var(--text-muted)">'+esc(String(e.message||e))+'</span></div>';}
  }
}
function closeReplay(){
  var modal=document.getElementById('replay-modal');
  if(!modal)return;
  modal.classList.remove('open');
  document.body.style.overflow='';
  if(window.OrbitReplay)window.OrbitReplay.pause();
}

function renderFleet(data){
  var subs=data.submissions||[];
  var el=document.getElementById('panel-fleet');
  if(!subs.length){el.innerHTML='<div class="empty">No submissions in the build log yet.</div>';return;}
  var html='<ul class="log">';
  subs.forEach(function(s){var burro=avatarFor(s.description);var n=num(s.publicScore);html+='<li><img class="av" src="images/'+burro+'-avatar.png" onerror="this.style.opacity=0.25" alt="'+burro+'" /><div class="body"><div class="msg">'+esc(s.description||s.fileName||'')+'</div><div class="sub"><span>'+esc((s.date||'').slice(0,16).replace('T',' '))+'</span>'+(n!==null?'<span class="score">'+n+'</span>':'')+pill(s.status)+'</div></div></li>';});
  html+='</ul>';
  el.innerHTML=html;
}

function render(data){
  LAST_DATA=data;
  var stamp=document.getElementById('stamp');if(stamp)stamp.textContent='updated '+ago(data.generated_at);
  renderShip(data);renderBattles(data);renderFleet(data);
  var ft=document.getElementById('footer');if(ft)ft.innerHTML='<a href="https://github.com/neonburro/orbit-wars" target="_blank" rel="noopener" style="color:var(--text-muted)">GitHub</a>  ·  <a href="https://www.kaggle.com/competitions/orbit-wars/leaderboard" target="_blank" rel="noopener" style="color:var(--text-muted)">Live Kaggle Leaderboard</a>  ·  Orbit Wars';
  startFlagClock();
}

var FLAG_CLOCK_TIMER=null;
function startFlagClock(){
  if(FLAG_CLOCK_TIMER)clearInterval(FLAG_CLOCK_TIMER);
  function tick(){
    var fc=document.getElementById('flag-clock');
    if(!fc)return;
    var card=document.querySelector('.flagship');
    if(!card)return;
    var dep=card.getAttribute('data-deployed');
    if(!dep){fc.textContent='';return;}
    var t=new Date(dep.replace(' ','T')+(dep.indexOf('Z')>-1?'':'Z')).getTime();
    if(isNaN(t)){fc.textContent='';return;}
    var s=Math.floor((Date.now()-t)/1000);
    if(s<0)s=0;
    var d=Math.floor(s/86400),h=Math.floor((s%86400)/3600),m=Math.floor((s%3600)/60),sec=s%60;
    var str='in service ';
    if(d>0)str+=d+'d ';
    if(d>0||h>0)str+=h+'h ';
    str+=m+'m '+sec+'s';
    fc.textContent=str;
  }
  tick();
  FLAG_CLOCK_TIMER=setInterval(tick,1000);
}



async function loadLive(){
  try{var res=await fetch('/.netlify/functions/refresh',{cache:'no-store'});if(res.ok){var d=await res.json();if(!d.error)return d;}}catch(e){}
  var r2=await fetch('data.json?_='+Date.now());return await r2.json();
}
async function loadRank(){
  try{var res=await fetch('/.netlify/functions/rank',{cache:'no-store'});if(res.ok)return await res.json();}catch(e){}
  return null;
}
var RANK_SYNCING=false;
async function triggerRankSync(){
  if(RANK_SYNCING)return;
  RANK_SYNCING=true;
  // mark the card as refreshing if we already have data showing
  var badge=document.getElementById('rank-refresh');
  if(badge)badge.style.display='inline-flex';
  try{
    var res=await fetch('/.netlify/functions/rank-sync',{cache:'no-store'});
    if(res.ok){
      var fresh=await res.json();
      if(fresh&&(fresh.found||fresh.syncing!==undefined)&&LAST_DATA){
        LAST_DATA.rank=fresh;
        renderShip(LAST_DATA);
        startFlagClock();
      }
    }
  }catch(e){}
  RANK_SYNCING=false;
}
async function load(spin){
  renderAgents();responsiveHero();
  var btn=document.getElementById('refresh-btn');
  if(spin&&btn)btn.classList.add('spinning');
  var data;
  try{data=await loadLive();}
  catch(e){var st=document.getElementById('stamp');if(st)st.textContent='no data loaded';if(btn)btn.classList.remove('spinning');return;}
  var rank=null;
  try{rank=await loadRank();if(rank)data.rank=rank;}catch(e){}
  render(data);
  if(btn)btn.classList.remove('spinning');
  // auto-trigger a background sync if rank is missing or stale, no manual click needed
  if(!rank||rank.stale||!rank.found){triggerRankSync();}
}

function setupReplayModal(){
  if(window.OrbitReplay)window.OrbitReplay.init();
  var close=document.getElementById('replay-close');
  if(close)close.onclick=closeReplay;
  var modal=document.getElementById('replay-modal');
  if(modal)modal.addEventListener('click',function(e){if(e.target===modal)closeReplay();});
  document.addEventListener('keydown',function(e){if(e.key==='Escape')closeReplay();});
}

window.addEventListener('resize',responsiveHero);
document.addEventListener('click',function(e){var b=e.target.closest&&e.target.closest('#refresh-btn');if(b)load(true);});
if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',function(){setupReplayModal();load(false);});}else{setupReplayModal();load(false);}
