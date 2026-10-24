# Requires lupa. These tests simulate the host; they do not run real audio plugins.
from pathlib import Path
from lupa import LuaRuntime
import tempfile
src=(Path(__file__).resolve().parents[1]/'Installer_Voix_Radio_FabFilter.lua').read_text()
mock=r'''
tracks={{original=true,fx={},values={B_MUTE=0}}}; existing=tracks[1]; messages={}; refresh=0
local function num(name,lo,hi) return {name=name,lo=lo,hi=hi,v=0} end
local function en(name,opts) return {name=name,opts=opts,v=0} end
local function params(name)
 local t={};local function n(k,a,b) t[#t+1]=num(k,a,b) end
 local function e(k,o) t[#t+1]=en(k,o) end
 if name:find('Pro%-Q') then
  e('Processing Mode',{'Zero Latency','Natural Phase'});n('Output Gain',-36,36);n('Gain Scale',0,200);n('Auto Gain',0,1);e('Character',{'Clean','Warm'});n('Output Pan',0,1);e('Output Pan Mode',{'Left/Right','Mid/Side'})
  for b=1,24 do local s='Band '..b..' ';n(s..'Used',0,1);n(s..'Enabled',0,1);n(s..'Solo',0,1);n(s..'Side Chain Audition',0,1);n(s..'External Side Chain',0,1);n(s..'Spectral Enabled',0,1);n(s..'Dynamics Enabled',0,1);n(s..'Dynamic Range',-30,30);e(s..'Stereo Placement',{'Left','Right','Stereo'});e(s..'Speakers',{'All (excl. LFE)'});e(s..'Shape',{'Bell','Low Cut','Low Shelf','High Shelf'});n(s..'Frequency',10,30000);n(s..'Q',.01,20);n(s..'Gain',-30,30);e(s..'Slope',{'6 dB/oct','12 dB/oct'}) end
 elseif name:find('Pro%-G') then
  e('Style',{'Clean','Vocal'});n('Threshold',-100,0);n('Ratio',1,20);n('Range',0,100);n('Attack',0,1000);n('Release',0,2000);n('Hold',0,1000);n('Lookahead',0,10)
 elseif name:find('Pro%-C 3') then
  e('Style',{'Clean','Vocal'});n('Threshold',-100,0);n('Ratio',1,20);n('Knee',0,60);n('Attack',0,1000);n('Release',0,2000);n('Auto Gain',0,1);n('Auto Release',0,1);n('Lookahead',0,20);n('Wet Gain',-36,36);e('Dry Gain',{'-INF dB','0 dB'})
 elseif name:find('Pro%-MB') then
  e('Processing Mode',SCENARIO=='badmode' and {'Dynamic Phase','Linear Phase'} or {'Dynamic Phase','Minimum Phase','Linear Phase'});n('Output Gain',-36,36)
  for b=1,6 do local s='Band '..b..' ';n(s..'Used',0,1);e(s..'Dynamics Mode',{'Compress','Expand'});n(s..'Output',-36,36);n(s..'Lookahead',0,20);n(s..'Low Crossover',10,30000);n(s..'High Crossover',10,30000);n(s..'Threshold',-100,0);n(s..'Range',-30,30);n(s..'Ratio',1,20);n(s..'Attack',0,100);n(s..'Release',0,100);n(s..'Knee',0,60) end
 else n('Gain sortie (dB)',-12,24);n('Plafond echantillons (dBFS)',-6,-.5) end
 return t
end
local function p(t,f,i) return t.fx[f+1].p[i+1] end
reaper={
 get_action_context=function() return false,ROOT..'/Installer.lua' end,
 GetResourcePath=function() return ROOT end,
 RecursiveCreateDirectory=function() end,
 GetSelectedTrack=function() return existing end,
 GetMediaTrackInfo_Value=function() return 0 end,
 CountTracks=function() return #tracks end,
 InsertTrackAtIndex=function() tracks[#tracks+1]={fx={},values={}} end,
 GetTrack=function(_,i) return tracks[i+1] end,
 GetSetMediaTrackInfo_String=function(t,k,v) t[k]=v end,
 SetMediaTrackInfo_Value=function(t,k,v) t.values[k]=v end,
 TrackFX_AddByName=function(t,name)
  if SCENARIO=='missing' and name:find('Pro%-C 3') then return -1 end
  t.fx[#t.fx+1]={name=name,p=params(name),enabled=true};return #t.fx-1
 end,
 TrackFX_SetPresetByIndex=function() return SCENARIO~='factory_unavailable' end,
 TrackFX_SetEnabled=function(t,f,e) t.fx[f+1].enabled=e end,
 TrackFX_GetNumParams=function(t,f) return #t.fx[f+1].p end,
 TrackFX_GetParamName=function(t,f,i) return true,p(t,f,i).name end,
 TrackFX_FormatParamValueNormalized=function(t,f,i,v)
  local a=p(t,f,i)
  if a.opts then return true,a.opts[math.min(#a.opts,math.floor(v*#a.opts)+1)] end
  return true,string.format('%.4f',a.lo+(a.hi-a.lo)*v)
 end,
 TrackFX_SetParamNormalized=function(t,f,i,v)
  local a=p(t,f,i)
  if SCENARIO=='quantized' and a.opts and #a.opts>1 then
    local idx=math.min(#a.opts-1,math.floor(v*#a.opts));v=idx/(#a.opts-1)
  end
  a.v=v
 end,
 TrackFX_GetParamNormalized=function(t,f,i) return p(t,f,i).v end,
 TrackFX_GetCount=function(t) return #t.fx end,
 TrackFX_GetFXName=function(t,f) return true,t.fx[f+1].name end,
 SetOnlyTrackSelected=function() end,
 Undo_BeginBlock=function() end,Undo_EndBlock=function() end,
 PreventUIRefresh=function(v) refresh=refresh+v end,
 TrackList_AdjustWindows=function() end,UpdateArrange=function() end,
 ShowConsoleMsg=function(s) console=s end,
 ShowMessageBox=function(s) messages[#messages+1]=s end
}
'''
for scenario in ['success','missing','badmode','factory_unavailable','quantized']:
 with tempfile.TemporaryDirectory() as root:
  Path(root,'Effects','RMixed').mkdir(parents=True)
  lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().ROOT=root;lua.globals().SCENARIO=scenario
  lua.execute(mock);lua.execute(src)
  lua.execute('assert(#tracks==2 and #existing.fx==0 and existing.values.B_MUTE==0);assert(refresh==0);assert(tracks[2].values.B_MUTE==1);assert(tracks[2].values.I_RECARM==0)')
  if scenario in ['success','factory_unavailable','quantized']:
   lua.execute("assert(#tracks[2].fx==6);for _,fx in ipairs(tracks[2].fx) do assert(fx.enabled) end;assert(tracks[2].fx[3].name=='VST3: Pro-C 3 (FabFilter)')")
   assert 'Configuration appliquee' in Path(root,'Rapport_FabFilter.txt').read_text()
   assert 'Processing Mode = Minimum Phase' in Path(root,'Rapport_FabFilter.txt').read_text()
  else:
   if scenario=='missing':
    lua.execute('assert(#tracks[2].fx==5)')
    assert 'Pro-MB' in Path(root,'Rapport_FabFilter.txt').read_text()
   lua.execute('for _,fx in ipairs(tracks[2].fx) do assert(not fx.enabled) end')
   assert 'NON APPLIQUE' in Path(root,'Rapport_FabFilter.txt').read_text()
  print(scenario, 'PASS')
