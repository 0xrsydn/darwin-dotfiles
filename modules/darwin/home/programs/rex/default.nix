# Rex server config for this Mac. The app resolves keys with this Mac's
# server config even while a remote host's session is in front, so the
# hermes-vm shortcuts are bound here; see init.lua.
{ ... }:
let
  rex = "$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex";
in
{
  xdg.configFile."rex/init.lua" = {
    source = ./init.lua;
    # Replace a hand-made file or link left from before Home Manager owned it.
    force = true;
    # The server doesn't watch the file. Skip quietly when Rex isn't running.
    onChange = ''
      if [ -x "${rex}" ]; then
        "${rex}" config reload >/dev/null 2>&1 || true
      fi
    '';
  };
}
