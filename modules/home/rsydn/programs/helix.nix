{ pkgs, lib, ... }: {
  programs.helix = {
    enable = lib.mkDefault true;
    settings = {
      theme = "gruber-darker";
      editor = {
        auto-save = {
          focus-lost = true;
          after-delay = {
            enable = true;
            timeout = 3000;
          };
        };
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
