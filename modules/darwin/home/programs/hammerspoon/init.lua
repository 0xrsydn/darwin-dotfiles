-- Paste screenshots into Claude Code running in Rex, on the Mac or on a
-- remote host.
--
-- A terminal can only send text, so Cmd+V with an image on the clipboard
-- pastes nothing into a remote session. While Rex is in front, Cmd+V with an
-- image (and no text) saves the image to /tmp/claude-shots on the Mac, copies
-- it to the same path on each remote, then types "@/tmp/claude-shots/<name>.png ".
-- The path is the same everywhere, so it works in local and remote panes
-- alike. Any other Cmd+V passes through to Rex untouched.

local REX_BUNDLE_ID = "com.superlogical.rex"
local DIR = "/tmp/claude-shots"
-- SSH destinations that get a copy of each image.
local REMOTES = { "hermes@hermes-vm" }

local function clipboardHasOnlyImage()
  local types = hs.pasteboard.typesAvailable()
  -- Finder file copies and rich text carry a string or URL too; let Rex
  -- paste those as usual.
  return types.image and not types.string and not types.URL
end

local function upload(remote, name, localPath, done)
  local script = 'ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" '
    .. '"mkdir -p ' .. DIR .. ' && cat > ' .. DIR .. '/$2" < "$3"'
  local task = hs.task.new("/bin/sh", function(code, _, stderr)
    if code ~= 0 then
      hs.alert.show("Screenshot upload to " .. remote .. " failed")
      print("claude-shots: " .. remote .. ": " .. (stderr or ""))
    end
    done()
  end, { "-c", script, "sh", remote, name, localPath })
  task:start()
end

local function pasteImage(app)
  local image = hs.pasteboard.readImage()
  if not image then
    return false
  end

  hs.fs.mkdir(DIR)
  local name = os.date("%Y%m%d-%H%M%S") .. ".png"
  local localPath = DIR .. "/" .. name
  if not image:saveToFile(localPath) then
    hs.alert.show("Could not save the screenshot")
    return true
  end

  local pending = #REMOTES
  local function typePath()
    hs.eventtap.keyStrokes("@" .. localPath .. " ", app)
  end
  if pending == 0 then
    typePath()
    return true
  end
  for _, remote in ipairs(REMOTES) do
    upload(remote, name, localPath, function()
      pending = pending - 1
      if pending == 0 then
        typePath()
      end
    end)
  end
  return true
end

local vKey = hs.keycodes.map["v"]

-- Global, so the tap is not garbage collected.
rexImagePaste = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  if event:getKeyCode() ~= vKey then
    return false
  end
  local flags = event:getFlags()
  if not flags:containExactly({ "cmd" }) then
    return false
  end
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= REX_BUNDLE_ID then
    return false
  end
  if not clipboardHasOnlyImage() then
    return false
  end
  return pasteImage(app)
end)
rexImagePaste:start()
