{ lib, stdenv, fetchzip, autoPatchelfHook }:
let
  version = "1.0.137";

  platformInfo = {
    x86_64-darwin = {
      name = "darwin-x64";
      ext = "zip";
      hash = "sha256-ZgzvpW8SAN0HP3Qh+aT1S+WrEoXkTZiL8/8z1w9p9Y0=";
    };
    aarch64-darwin = {
      name = "darwin-arm64";
      ext = "zip";
      hash = "sha256-w5hs5arVroLtjr9pRAHYXQL+4L5gw1bJVL4DhgvrpLs=";
    };
    x86_64-linux = {
      name = "linux-x64";
      ext = "tar.gz";
      hash = "sha256-N8IR3xq/dGF5jPq9/UW8Mu/PnAUb7r+Ox6nge6wKw1M=";
    };
    aarch64-linux = {
      name = "linux-arm64";
      ext = "tar.gz";
      hash = "sha256-LwWbTAVnfEmCjUBNf58bgFFVVvDIQVJkLsGtYX+/EfU=";
    };
  };

  platform = platformInfo.${stdenv.hostPlatform.system} or (throw
    "Unsupported system: ${stdenv.hostPlatform.system}");
in stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchzip {
    url =
      "https://github.com/sst/opencode/releases/download/v${version}/opencode-${platform.name}.${platform.ext}";
    hash = platform.hash;
    stripRoot = false;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp opencode $out/bin/opencode
    chmod +x $out/bin/opencode
    runHook postInstall
  '';

  meta = {
    description = "AI coding assistant CLI from SST";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms =
      [ "x86_64-darwin" "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
  };
}
