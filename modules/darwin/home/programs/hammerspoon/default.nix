# Hammerspoon config. The app itself comes from the Homebrew cask in
# modules/darwin/homebrew.nix. It needs Accessibility access (System Settings >
# Privacy & Security) for the key handling in init.lua.
{ ... }:
{
  home.file.".hammerspoon/init.lua".source = ./init.lua;
}
