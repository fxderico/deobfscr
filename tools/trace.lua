-- Wrap bit32 + string functions with tracing (logs to LOG via rprint-style table)
TRACE = {}
local rawconcat = table.concat
local function tlog(...)
  local parts = {}
  for i,v in ipairs({...}) do parts[#parts+1] = tostring(v) end
  table.insert(TRACE, rawconcat(parts, "\t"))
end

local rawpack, rawunpack = table.pack, table.unpack
local function wrap(tbl, name)
  local orig = tbl[name]
  tbl[name] = function(...)
    local n = select("#", ...)
    local args = rawpack(...)
    local ret = rawpack(pcall(orig, ...))
    local ok = ret[1]
    local argstrs = {}
    for i=1,n do argstrs[i] = tostring(args[i]) end
    if ok then
      local retstrs = {}
      for i=2,ret.n do retstrs[#retstrs+1] = tostring(ret[i]) end
      tlog("CALL", name, "n="..n, rawconcat(argstrs, ","), "->", rawconcat(retstrs, "|"))
      return rawunpack(ret, 2, ret.n)
    else
      tlog("ERRCALL", name, "n="..n, rawconcat(argstrs, ","), "ERR:", tostring(ret[2]))
      error(ret[2], 0)
    end
  end
end

wrap(bit32, "rshift")
wrap(bit32, "band")
wrap(bit32, "bxor")
wrap(bit32, "lshift")
wrap(bit32, "bor")
wrap(string, "char")
wrap(string, "byte")
wrap(string, "sub")
wrap(string, "rep")
wrap(string, "format")
wrap(string, "find")
