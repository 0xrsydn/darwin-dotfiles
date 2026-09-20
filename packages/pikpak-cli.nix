{
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  version = "0.5.2";
  sources = {
    aarch64-darwin = {
      asset = "pikpak_darwin_arm64";
      hash = "sha256-MG4c+2sSg0s2xKOHq17oEOVg29Z6Pojo8AuGHeo992U=";
    };
    x86_64-darwin = {
      asset = "pikpak_darwin_amd64";
      hash = "sha256-NKZe0qPxz+dQAnCaDOLWeBIJiahFsiqRztmCi25T6bA=";
    };
    aarch64-linux = {
      asset = "pikpak_linux_arm64";
      hash = "sha256-L1UChjwK7Edy8dYsS2aiAYA905FlKh79VxtiOE4As+s=";
    };
    x86_64-linux = {
      asset = "pikpak_linux_amd64";
      hash = "sha256-9pdJnLNWRbpMnnn/+fbq/QAydD8IxuzvMnaI5Ozs4UA=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "pikpak-cli";
  inherit version;

  src = fetchurl {
    url = "https://download.mypikpak.com/cli/release/v${version}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/pikpak"

    runHook postInstall
  '';

  meta = {
    description = "Command-line client for PikPak cloud storage";
    homepage = "https://mypikpak.com/en-US/cli";
    license = lib.licenses.unfree;
    mainProgram = "pikpak";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
