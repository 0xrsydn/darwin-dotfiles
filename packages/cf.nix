{
  lib,
  stdenv,
  buildNpmPackage,
  nodejs_22,
  makeWrapper,
  autoPatchelfHook,
  llvmPackages,
}:
buildNpmPackage (finalAttrs: {
  pname = "cf";
  version = (lib.importJSON ./cf/package.json).dependencies.cf;

  # Use the published CLI bundle. The upstream source build needs a monorepo.
  src = ./cf;
  nodejs = nodejs_22;
  npmDepsHash = "sha256-8acS8VekfuKmihOUsq44Ba5xZ4Qr2Mbf89anb/THvTM=";
  dontNpmBuild = true;

  # Native dependencies ship platform-specific binaries in optional packages.
  # Disable install scripts that can download binaries outside the Nix cache.
  npmFlags = [ "--ignore-scripts" ];
  npmInstallFlags = lib.optionals stdenv.hostPlatform.isLinux [ "--libc=glibc" ];

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    llvmPackages.libcxx
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib" "$out/bin"
    cp -r node_modules "$out/lib/"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/cf" \
      --add-flags "$out/lib/node_modules/cf/bin/cf"
    ln -s cf "$out/bin/cloudflare"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/cf-home"
    mkdir -p "$HOME"
    "$out/bin/cf" --version | grep -F '${finalAttrs.version}'
    "$out/bin/cloudflare" --help > /dev/null
    "$out/lib/node_modules/.bin/workerd" --version
    NODE_PATH="$out/lib/node_modules" ${lib.getExe nodejs_22} -e 'require("sharp")'

    runHook postInstallCheck
  '';

  meta = {
    description = "Command-line interface for the Cloudflare API";
    homepage = "https://github.com/cloudflare/cf";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "cf";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
