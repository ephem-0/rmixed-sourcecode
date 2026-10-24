-- REAPER 7 / Lua. Builds a separate, initially muted and disarmed track.
-- No original track, item, hardware route or plugin instance is modified.
-- Parameter discovery uses names and the plugin's displayed values, never assumed indices.
local r = reaper
local _, script_path = r.get_action_context()
local dir = script_path:match('^(.*[\\/])') or ''
local report, errors = {}, {}
local track, indices
local function log(s) report[#report+1] = s end
local function problem(s) errors[#errors+1]=s; log('NON APPLIQUE : '..s) end
local function norm(s)
  return (s:lower():gsub('[^%w]', ''))
end
local function dbnum(s)
  s=s:lower():gsub('−','-'):gsub(',','.')
  local v=tonumber(s:match('[-+]?%d*%.?%d+'))
  if v and s:find('khz',1,true) then v=v*1000 end
  return v
end
local function named(fx, names, optional)
  if type(names)=='string' then names={names} end
  for _, name in ipairs(names) do
    for i=0,r.TrackFX_GetNumParams(track,fx)-1 do
      local ok,s=r.TrackFX_GetParamName(track,fx,i,'')
      if ok and norm(s)==norm(name) then return i,s end
    end
  end
  if not optional then problem('FX '..fx..' / parametre '..table.concat(names,' | ')) end
end
local function formatted(fx,p,v)
  local ok,s=r.TrackFX_FormatParamValueNormalized(track,fx,p,v,'')
  return ok and s or ''
end
local function apply(fx,p,v,label)
  r.TrackFX_SetParamNormalized(track,fx,p,v)
  local got=r.TrackFX_GetParamNormalized(track,fx,p)
  if math.abs(got-v)>0.002 then problem(label..' : ecriture non conservee');return false end
  log(label..' = '..formatted(fx,p,got))
  return true
end
local function value(fx,names,target,tolerance,optional)
  local p,label=named(fx,names,optional);if not p then return false end
  local best,err
  -- Search actual plugin display mappings, including logarithmic frequency/time controls.
  for i=0,1024 do
    local v=i/1024;local n=dbnum(formatted(fx,p,v))
    if n then local e=math.abs(n-target);if not err or e<err then best=v;err=e end end
  end
  if not best then problem(label..' : affichage numerique inexploitable');return false end
  for _=1,3 do
    local step=1/1024;local lo=math.max(0,best-step);local hi=math.min(1,best+step)
    for i=0,64 do
      local v=lo+(hi-lo)*i/64;local n=dbnum(formatted(fx,p,v))
      if n and math.abs(n-target)<err then best=v;err=math.abs(n-target) end
    end
  end
  if err>(tolerance or .15) then problem(label..' : cible '..target..' hors correspondance fiable');return false end
  if not apply(fx,p,best,label) then return false end
  local n=dbnum(formatted(fx,p,r.TrackFX_GetParamNormalized(track,fx,p)))
  if not n or math.abs(n-target)>(tolerance or .15) then problem(label..' : lecture finale differente');return false end
  return true
end
local function choice(fx,names,wanted,optional)
  local p,label=named(fx,names,optional);if not p then return false end
  if type(wanted)=='string' then wanted={wanted} end
  for _,w in ipairs(wanted) do
    for i=0,256 do
      local v=i/256
      if norm(formatted(fx,p,v))==norm(w) then return apply(fx,p,v,label) end
    end
  end
  problem(label..' : option '..table.concat(wanted,' | ')..' introuvable');return false
end
local function flag(fx,names,on,optional)
  local p,label=named(fx,names,optional);if not p then return false end
  -- Only names explicitly expressing a binary switch may use endpoints.
  return apply(fx,p,on and 1 or 0,label)
end
local function bandnames(b,fields)
  if type(fields)=='string' then fields={fields} end
  local a={};for _,f in ipairs(fields) do a[#a+1]='Band '..b..' '..f end;return a
end
local function bv(fx,b,f,v,t) return value(fx,bandnames(b,f),v,t) end
local function bc(fx,b,f,c) return choice(fx,bandnames(b,f),c) end
local function used(fx,b,on)
  return flag(fx,bandnames(b,{'Used','Enabled'}),on)
end
local function add(name)
  local fx=r.TrackFX_AddByName(track,name,false,-1)
  if fx<0 then error('Plugin introuvable : '..name) end
  r.TrackFX_SetEnabled(track,fx,false)
  -- REAPER API: -1 requests the factory preset, avoiding a custom user default.
  if not r.TrackFX_SetPresetByIndex(track,fx,-1) then
    error('Impossible de charger le preset usine : '..name)
  end
  return fx
end
local safety=[=[desc:RMixed - Securite radio (1 ms)
slider1:12<-12,24,0.1>Gain sortie (dB)
slider2:-1.5<-6,-0.5,0.1>Plafond echantillons (dBFS)
in_pin:L
in_pin:R
out_pin:L
out_pin:R
@init
n=max(1,floor(srate*.001));pos=0;g=1;hold=0;
memset(0,0,n*2);pdc_delay=n;pdc_bot_ch=0;pdc_top_ch=2;
@slider
makeup=10^(slider1/20);ceiling=10^(slider2/20);rel=exp(-1/(srate*.060));
@sample
l=spl0*makeup;rr=spl1*makeup;pk=max(abs(l),abs(rr));need=min(1,ceiling/max(pk,.000000001));
need<g ? (g=need;hold=n;) : (hold>0 ? hold-=1 : g=rel*g+(1-rel));
ol=pos[0];orr=(pos+n)[0];pos[0]=l;(pos+n)[0]=rr;
spl0=max(-ceiling,min(ceiling,ol*g));spl1=max(-ceiling,min(ceiling,orr*g));
pos=(pos+1)%n;
]=]
local function install_safety()
  local folder=r.GetResourcePath()..'/Effects/RMixed'
  r.RecursiveCreateDirectory(folder,0)
  local path=folder..'/RadioSafety.jsfx'
  local f=io.open(path,'rb');local existing
  if f then existing=f:read('*a');f:close() end
  if existing and existing~=safety then error('Effet local deja different : '..path..'. Aucun ecrasement.') end
  if not existing then
    f=assert(io.open(path,'wb'),'Impossible de creer la securite JSFX')
    f:write(safety);f:close()
  end
end
local function build()
  install_safety()
  local selected=r.GetSelectedTrack(0,0)
  local recinput=selected and r.GetMediaTrackInfo_Value(selected,'I_RECINPUT') or 0
  if recinput<0 or recinput>=1024 then recinput=0 end
  r.InsertTrackAtIndex(r.CountTracks(0),true)
  track=r.GetTrack(0,r.CountTracks(0)-1)
  r.GetSetMediaTrackInfo_String(track,'P_NAME','RADIO FabFilter - verification',true)
  r.SetMediaTrackInfo_Value(track,'B_MUTE',1)
  r.SetMediaTrackInfo_Value(track,'I_RECARM',0)
  r.SetMediaTrackInfo_Value(track,'I_RECMON',0)
  r.SetMediaTrackInfo_Value(track,'I_RECINPUT',recinput)
  local q=add('VST3: Pro-Q 4 (FabFilter)')
  local gate=add('VST3: Pro-G (FabFilter)')
  local c=add('VST3: Pro-C 3 (FabFilter)')
  local m1=add('VST3: Pro-MB (FabFilter)')
  local m2=add('VST3: Pro-MB (FabFilter)')
  local lim=add('JS: RMixed/RadioSafety.jsfx')
  indices={q,gate,c,m1,m2,lim}
  -- Static voice EQ, minimum/zero-latency phase. No fabricated preset blob.
  log('\nPRO-Q 4')
  choice(q,{'Processing Mode','Processing'},{'Zero Latency'})
  value(q,{'Output Gain','Output Level'},8)
  value(q,'Gain Scale',100,1,true)
  for b=1,24 do used(q,b,false) end
  local bands={
    {type={'Low Cut','High Pass'},freq=65,q=.707,slope={'12 dB/oct','12 dB/octave','12 dB'}},
    {type={'Low Shelf'},freq=125,q=.707,gain=2},
    {type={'Bell'},freq=330,q=1,gain=-3},
    {type={'Bell'},freq=2800,q=.8,gain=3},
    {type={'High Shelf'},freq=8000,q=.707,gain=1.5}
  }
  for b,s in ipairs(bands) do
    used(q,b,true);bc(q,b,{'Shape','Type'},s.type)
    bv(q,b,{'Frequency','Freq'},s.freq,math.max(1,s.freq*.015));bv(q,b,'Q',s.q,.06)
    if s.gain then bv(q,b,'Gain',s.gain,.1) end
    if s.slope then bc(q,b,'Slope',s.slope) end
    flag(q,bandnames(b,'Dynamic Enabled'),false,true)
  end
  log('\nPRO-G : expansion douce, pas de gate brutal')
  choice(gate,'Style',{'Vocal','Clean'})
  value(gate,'Threshold',-46);value(gate,'Ratio',1.6,.06);value(gate,'Range',12,.2)
  value(gate,'Attack',3,.3);value(gate,'Release',140,3);value(gate,'Hold',30,2)
  value(gate,{'Lookahead','Look Ahead'},0,.01)
  value(gate,{'Output Gain','Output Level'},0,.1,true)
  flag(gate,{'External Side Chain','External Sidechain'},false,true)
  log('\nPRO-C 3 : voix stable, transitoires conservees')
  choice(c,'Style',{'Clean'})
  value(c,'Threshold',-25);value(c,'Ratio',3.5,.06);value(c,'Knee',6,.2)
  value(c,'Attack',5,.3);value(c,'Release',100,3)
  flag(c,'Auto Gain',false);flag(c,'Auto Release',false)
  value(c,{'Lookahead','Look Ahead'},0,.01)
  value(c,{'Wet Gain','Output Gain','Output Level'},0,.1)
  choice(c,{'Dry Gain','Dry Level'},{'-INF dB','-inf','-infinity dB','-oo dB'})
  flag(c,{'External Side Chain','External Sidechain'},false,true)
  choice(c,'Oversampling',{'Off','1x','Disabled','None'},true)
  -- Both Pro-MBs have only one active band; no five-band loudness preset.
  for _,fx in ipairs({m1,m2}) do
    for b=1,6 do used(fx,b,false) end
    used(fx,1,true)
    bc(fx,1,{'Dynamics Mode','Mode'},{'Compress','Compression'})
    bv(fx,1,{'Output','Output Gain','Gain'},0,.1)
    value(fx,{'Output Gain','Output Level'},0,.1)
    bv(fx,1,{'Lookahead','Look Ahead'},0,.01)
    flag(fx,bandnames(1,{'External Side Chain','External Sidechain'}),false,true)
    choice(fx,'Oversampling',{'Off','1x','Disabled','None'},true)
  end
  log('\nPRO-MB 1 : bas-medium dynamique')
  choice(m1,{'Processing Mode','Processing'},{'Dynamic Phase'})
  bv(m1,1,{'Low Crossover','Low Frequency','Low Crossover Frequency'},100,2)
  bv(m1,1,{'High Crossover','High Frequency','High Crossover Frequency'},350,5)
  bv(m1,1,'Threshold',-26);bv(m1,1,'Range',-3);bv(m1,1,'Ratio',1.6,.06)
  bv(m1,1,'Attack',25,1);bv(m1,1,'Release',35,1);bv(m1,1,'Knee',6,.2)
  log('\nPRO-MB 2 : sifflantes, MINIMUM PHASE')
  choice(m2,{'Processing Mode','Processing'},{'Minimum Phase'})
  bv(m2,1,{'Low Crossover','Low Frequency','Low Crossover Frequency'},4500,60)
  bv(m2,1,{'High Crossover','High Frequency','High Crossover Frequency'},11000,150)
  bv(m2,1,'Threshold',-34);bv(m2,1,'Range',-4);bv(m2,1,'Ratio',3,.06)
  bv(m2,1,'Attack',5,1);bv(m2,1,'Release',20,1);bv(m2,1,'Knee',6,.2)
  log('\nSECURITE DE SORTIE')
  value(lim,'Gain sortie (dB)',12,.1);value(lim,'Plafond echantillons (dBFS)',-1.5,.1)
  -- All FX remain bypassed unless EVERY required/recognized setting was applied.
  if #errors==0 then
    for _,fx in ipairs(indices) do r.TrackFX_SetEnabled(track,fx,true) end
    r.GetSetMediaTrackInfo_String(track,'P_NAME','RADIO FabFilter - 2 Pro-MB',true)
    log('\nConfiguration appliquee. Piste volontairement mutee, desarmee, monitoring coupe.')
    log('Choisir entree mono, ecouter au casque et regler le niveau avant usage.')
  else
    r.GetSetMediaTrackInfo_String(track,'P_NAME','RADIO - parametres a verifier (FX bypass)',true)
    log('\nConfiguration INCOMPLETE : piste mutee, tous les FX restent bypasses.')
  end
  r.SetOnlyTrackSelected(track)
end
r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local ok,err=xpcall(build,debug.traceback)
if not ok then problem(tostring(err)) end
if #errors>0 and track then
  r.SetMediaTrackInfo_Value(track,'B_MUTE',1)
  for fx=0,r.TrackFX_GetCount(track)-1 do r.TrackFX_SetEnabled(track,fx,false) end
end
if track then
  log('\nINVENTAIRE REEL DES PARAMETRES (pour adaptation sans captures)')
  for fx=0,r.TrackFX_GetCount(track)-1 do
    local _,name=r.TrackFX_GetFXName(track,fx,'');log('\n'..fx..' : '..name)
    for p=0,r.TrackFX_GetNumParams(track,fx)-1 do
      local _,name=r.TrackFX_GetParamName(track,fx,p,'')
      local v=r.TrackFX_GetParamNormalized(track,fx,p)
      log(string.format('%d | %s | %.6f | %s',p,name,v,formatted(fx,p,v)))
    end
  end
end
r.PreventUIRefresh(-1)
r.TrackList_AdjustWindows(false)
r.UpdateArrange()
r.Undo_EndBlock('Creer une piste voix radio FabFilter, deux Pro-MB',-1)
local text=table.concat(report,'\n')
local path=dir..'Rapport_FabFilter.txt'
local f=io.open(path,'wb')
if f then f:write(text);f:close() else path='console REAPER (fichier non accessible)' end
r.ShowConsoleMsg('\n'..text..'\n')
local msg
if #errors==0 then
  msg='Chaine appliquee sur une NOUVELLE piste, mutee et desarmee.\n\nChoisis ton entree micro MONO. Pour essayer au casque : demute, arme et active le monitoring. Evite le double monitoring avec ta piste actuelle.\n\nLe second Pro-MB est en Minimum Phase.\nRapport : '..path
else
  msg='La configuration automatique n\'est pas complete. La nouvelle piste reste mutee et les FX bypasses. Ta piste originale est intacte.\n\nEnvoie Rapport_FabFilter.txt dans la conversation : il contient les vrais noms des parametres, sans licence. Aucune capture necessaire.\n\nRapport : '..path
end
r.ShowMessageBox(msg,'Voix radio FabFilter',0)
