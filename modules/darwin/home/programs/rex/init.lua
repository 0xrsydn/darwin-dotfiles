-- Rex server configuration for this Mac, linked to ~/.config/rex/init.lua by
-- default.nix. After a rebuild, run `rex config reload`.
--
-- The app resolves keys with this Mac's keymap even while a hermes-vm
-- session is in front, so hermes-vm's own bindings never fire from here.
-- This file copies them: each key hermes-vm binds to one of its init.lua
-- actions runs that action on hermes-vm through the CLI, and its prompts
-- come back to this app. The actions and their keys stay in hermes-vm's
-- config (personal-clan-nix); after changing it, run `rex config reload`
-- on hermes-vm and then here.

local HOME = os.getenv("HOME")
local HERMES = "https://hermes-vm.tail2b4d49.ts.net:7297"
-- The server's PATH is /usr/bin:/bin:/usr/sbin:/sbin, so name the CLI that
-- ships with the server.
local REX = HOME .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
local LOG = HOME .. "/Library/Logs/rex-hermes-actions.log"
-- The last keymap hermes-vm sent, so its keys survive a reload while it's
-- unreachable.
local CACHE = HOME .. "/Library/Caches/rex-hermes-keymap.json"
-- Seconds a load waits for hermes-vm before it falls back to the cache.
local FETCH_TIMEOUT = 5
-- Seconds to wait for a remote action that fails before it asks anything,
-- such as attach_agent with no hc terminals, so its error shows in the app.
local QUICK_FAILURE = 3

local function log(msg)
  local f = io.open(LOG, "a")
  if f ~= nil then
    f:write(os.date("%Y-%m-%dT%H:%M:%S "), msg, "\n")
    f:close()
  end
end

local function read_file(path)
  local f = io.open(path, "r")
  if f == nil then
    return nil
  end
  local text = f:read("*a")
  f:close()
  return text
end

local function write_file(path, text)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if f == nil then
    return
  end
  f:write(text)
  f:close()
  os.rename(tmp, path)
end

local function last_line(path)
  local last
  for line in (read_file(path) or ""):gmatch("[^\n]+") do
    if line:match("%S") then
      last = line
    end
  end
  return last
end

local function decode(text)
  local ok, v = pcall(rex.json.decode, text or "")
  if ok then
    return v
  end
  return nil
end

-- Run a command against hermes-vm and return its decoded JSON output.
local function hermes_json(argv)
  local cmd = { REX, "-S", HERMES }
  for _, a in ipairs(argv) do
    cmd[#cmd + 1] = a
  end
  local r = rex.exec(cmd, { timeout = FETCH_TIMEOUT })
  if r == nil or not r.ok then
    return nil, r
  end
  return decode(r.stdout), r
end

local function require_hermes(ctx)
  if ctx.server == nil or ctx.server:find("hermes-vm", 1, true) ~= 1 then
    error("Switch to a hermes-vm session first.", 0)
  end
end

-- Run hermes-vm's action `name` without waiting. An action here has 30
-- seconds, and the remote prompt waits for me longer than that.
--
-- While a hermes-vm session is in front, ctx.server is that host's label and
-- ctx.session_id/ctx.block_id are the remote session and focused pane, so
-- the remote action opens its windows where I'm looking.
local function run_remote(ctx, name, args)
  log(name .. " session=" .. tostring(ctx.session_id) .. " block=" .. tostring(ctx.block_id))
  require_hermes(ctx)
  -- sh appends the CLI's output to the log, so a failure leaves a trace.
  local argv = { "/bin/sh", "-c", 'log=$1; shift; exec "$@" >>"$log" 2>&1', "sh", LOG }
  for _, a in ipairs({ REX, "-S", HERMES, "-s", ctx.session_id }) do
    argv[#argv + 1] = a
  end
  if ctx.block_id ~= nil then
    argv[#argv + 1] = "-b"
    argv[#argv + 1] = ctx.block_id
  end
  for _, a in ipairs({ "do", name, "--origin", ctx.origin == "key" and "key" or "palette" }) do
    argv[#argv + 1] = a
  end
  if args ~= nil and next(args) ~= nil then
    argv[#argv + 1] = "--args"
    argv[#argv + 1] = rex.json.encode(args)
  end
  local h, err = rex.exec.start(argv, { detach = true, stdout = false, stderr = false })
  if h == nil then
    error(err, 0)
  end
  -- A remote prompt keeps the command running, so a timeout here is the
  -- normal case, and the command carries on detached.
  local r = h:wait(QUICK_FAILURE)
  if r ~= nil and not r.ok then
    local msg = last_line(LOG) or ("exit " .. tostring(r.code))
    error((msg:gsub("^Error: ", "")), 0)
  end
end

-- One action runs any hermes-vm action: keys pass its name as `action`, and
-- the command palette asks for one.
rex.action{
  name = "hermes",
  title = "hermes-vm: Run Action…",
  category = "hermes-vm",
  run = function(ctx, args)
    require_hermes(ctx)
    local name = args.action
    if name == nil then
      local list = hermes_json({ "actions", "--json" })
      local items = {}
      for _, a in ipairs((list and list.actions) or {}) do
        -- Dotted names are block methods; init.lua actions have no dot.
        if a.title ~= nil and not a.name:find(".", 1, true) then
          items[#items + 1] = { id = a.name, title = a.title, subtitle = a.description }
        end
      end
      if #items == 0 then
        error("hermes-vm didn't list any actions.", 0)
      end
      name = rex.ui.pick{ title = "Run on hermes-vm", items = items }
      if name == nil then
        return
      end
    end
    run_remote(ctx, name, args.args)
  end,
}

-- Copy hermes-vm's bindings. Fetch them now, or use the last copy.
local function hermes_bindings()
  local keymap, r = hermes_json({ "keymap", "--json" })
  if keymap ~= nil and keymap.bindings ~= nil then
    write_file(CACHE, rex.json.encode(keymap))
    return keymap.bindings, "hermes-vm"
  end
  local why = r == nil and "not reachable" or (r.timed_out and "timed out" or r.stderr)
  rex.log("hermes-vm keymap unavailable (" .. tostring(why) .. "), using " .. CACHE)
  local cached = decode(read_file(CACHE))
  return (cached and cached.bindings) or {}, "cache"
end

local bindings, from = hermes_bindings()
local count = 0
for _, b in ipairs(bindings) do
  -- Only hermes-vm's own init.lua actions, outside modes. A dotted action
  -- is the app's or a block's, which this Mac's keymap already handles.
  if b.mode == nil and b.action ~= nil and not b.action:find(".", 1, true) then
    rex.bind(table.concat(b.keys, ">"), "hermes", { action = b.action, args = b.args })
    count = count + 1
  end
end
rex.log("copied " .. count .. " hermes-vm bindings from " .. from)
