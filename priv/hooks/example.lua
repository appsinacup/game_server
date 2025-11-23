-- Example Lua hook script for GameServer.Hooks.LuaInvoker
-- Usage: lua example.lua <hook_name>

local hook = arg[1] or ""

-- Read payload from stdin (not used in this example)
io.read("*a")

-- Simple OK response; a real script should parse JSON and return structured JSON
print('{"result":"ok","data":{"hook":"' .. hook .. '"}}')
