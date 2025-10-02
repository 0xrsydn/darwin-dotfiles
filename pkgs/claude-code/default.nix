{ lib, stdenv, fetchurl, nodejs }:

stdenv.mkDerivation rec {
  pname = "claude-code";
  version = "2.0.0";

  src = fetchurl {
    url =
      "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash =
      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update with actual hash
  };

  nativeBuildInputs = [ nodejs ];

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    mkdir -p $out/lib/node_modules/@anthropic-ai/claude-code
    cp -r package/* $out/lib/node_modules/@anthropic-ai/claude-code/

    mkdir -p $out/bin
    ln -s $out/lib/node_modules/@anthropic-ai/claude-code/cli.js $out/bin/claude-code
    chmod +x $out/bin/claude-code
  '';

  meta = with lib; {
    description = "Anthropic Claude Code CLI v2.0.0";
    homepage = "https://claude.ai/code";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = platforms.all;
    mainProgram = "claude-code";
  };
}
