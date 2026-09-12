-- Polyfills + instrumentation for running a Luau/Lua5.1-targeted obfuscated
-- chunk under fengari (Lua 5.3 semantics). Goal: dynamic/behavioral analysis
-- -- capture what the VM actually does (globals touched, strings used,
-- "http"-like calls) rather than full static devirtualization.

LOG = {}
local function logf(fmt, ...)
  local ok, s = pcall(string.format, fmt, ...)
  table.insert(LOG, ok and s or fmt)
end

-- ===== bit32 polyfill (Lua 5.1/Luau lib) using native 5.3 bitwise ops =====
local function toint(x) return x & 0xFFFFFFFF end
bit32 = {}
function bit32.band(a,b,...) local r=toint(a)&toint(b) for _,v in ipairs({...}) do r=r&toint(v) end return toint(r) end
function bit32.bor(a,b,...) local r=toint(a)|toint(b) for _,v in ipairs({...}) do r=r|toint(v) end return toint(r) end
function bit32.bxor(a,b,...) local r=toint(a)~toint(b) for _,v in ipairs({...}) do r=r~toint(v) end return toint(r) end
function bit32.bnot(a) return toint(~toint(a)) end
function bit32.lshift(a,n) if n<=-32 or n>=32 then return 0 end if n>=0 then return toint(toint(a)<<n) else return toint(toint(a)>>(-n)) end end
function bit32.rshift(a,n) if n<=-32 or n>=32 then return 0 end if n>=0 then return toint(toint(a)>>n) else return toint(toint(a)<<(-n)) end end
function bit32.arshift(a,n)
  a = toint(a)
  if n<0 then return bit32.lshift(a,-n) end
  if n>=32 then if a & 0x80000000 ~= 0 then return 0xFFFFFFFF else return 0 end end
  if a & 0x80000000 ~= 0 then
    return toint((a>>n) | (0xFFFFFFFF << (32-n)))
  else
    return toint(a>>n)
  end
end
function bit32.btest(...) return bit32.band(...) ~= 0 end
function bit32.extract(a,field,width)
  width = width or 1
  return toint((toint(a) >> field) & ((1<<width)-1))
end
function bit32.replace(a,v,field,width)
  width = width or 1
  local mask = ((1<<width)-1) << field
  return toint((toint(a) & ~mask) | ((toint(v) << field) & mask))
end

-- getfenv/setfenv shims (removed in 5.2+)
if not getfenv then
  getfenv = function(_) return _G end
end
if not setfenv then
  setfenv = function(f, _) return f end
end

-- ===== instrumented fake Roblox environment =====
local function tracked(name)
  local t = {}
  local mt = {}
  mt.__index = function(tbl, k)
    logf("INDEX %s.%s", name, tostring(k))
    return tracked(name .. "." .. tostring(k))
  end
  mt.__call = function(tbl, ...)
    local args = {...}
    local parts = {}
    for i=2,#args do parts[#parts+1] = tostring(args[i]) end
    logf("CALL %s(%s)", name, table.concat(parts, ", "))
    return tracked(name .. "()")
  end
  mt.__tostring = function() return "<tracked:" .. name .. ">" end
  mt.__concat = function(a,b) return tostring(a)..tostring(b) end
  return setmetatable(t, mt)
end

game = tracked("game")
workspace = tracked("workspace")
script = tracked("script")
Instance = tracked("Instance")
Enum = tracked("Enum")
task = tracked("task")
Vector3 = tracked("Vector3")
CFrame = tracked("CFrame")
Color3 = tracked("Color3")
UDim2 = tracked("UDim2")
syn = tracked("syn")
identifyexecutor = function() return "fengari-sandbox", "1.0" end
wait = function(t) logf("CALL wait(%s)", tostring(t)) return 0 end
spawn = function(f) logf("CALL spawn(<function>)") return f end
delay = function(t,f) logf("CALL delay(%s, <function>)", tostring(t)) end
tick = function() return 0 end
os.clock = os.clock or function() return 0 end

-- Intercept load/loadstring so we can see exactly what source the script
-- tries to compile/run (e.g. a remote-fetched second stage), without
-- actually executing untrusted fetched content.
local reallload, reallloadstring = load, loadstring
local function fakeloader(name)
  return function(src, ...)
    logf("LOADCALL %s(%s)", name, tostring(src))
    return function(...) logf("would-have-run %s result", name) end
  end
end
load = fakeloader("load")
loadstring = fakeloader("loadstring")

local realprint = print
rprint = realprint
print = function(...)
  local parts = {}
  for i,v in ipairs({...}) do parts[#parts+1] = tostring(v) end
  logf("PRINT %s", table.concat(parts, "\t"))
end
