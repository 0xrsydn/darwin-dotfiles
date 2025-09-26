{ pkgs, lib, ... }: {
  programs.helix = {
    enable = lib.mkDefault true;
    settings = {
      theme = "gruber-darker";
      editor = {
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
      };
    };
    languages.language = [{
      name = "nix";
      auto-format = true;
      formatter.command = "${pkgs.nixfmt-classic}/bin/nixfmt";
    }];
  };
}
