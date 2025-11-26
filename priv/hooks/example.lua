-- Example Lua hook script for GameServer.Hooks.LuaInvoker
-- Usage: lua example.lua <hook_name>

local hook = arg[1] or ""

-- Read full JSON payload from STDIN
local payload = io.read("*a") or ""

-- Trim whitespace/newlines
payload = payload:gsub("^%s+", ""):gsub("%s+$", "")

-- Print a log message to STDERR so it doesn't interfere with the JSON stdout
io.stderr:write(string.format("[lua-hook] hook=%s payload=%s\n", hook, payload))

-- If payload is empty, return null data; otherwise embed the original JSON payload
if payload == "" then
	print('{"result":"ok","data":null}')
else
	-- We assume the incoming payload is valid JSON and echo it back inside "data".
	-- This lets the Elixir side (Jason) decode `data` back into the original structure.
	io.write('{"result":"ok","data":')
	io.write(payload)
	io.write('}')
end
