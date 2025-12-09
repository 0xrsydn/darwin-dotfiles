{ lib, buildNpmPackage, fetchurl, python3 }:

buildNpmPackage rec {
  pname = "osgrep";
  version = "0.5.16";

  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-V23PNxtMCdRaqr4uDOs0rptmSROUrUO7I9HazoGqUCQ=";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./osgrep-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-JDeZ3kcsbcZM//0846i1gsvoAgMpIpN8c160cp7wB5s=";

  npmFlags = [ "--legacy-peer-deps" ];

  dontNpmBuild = true; # Already built in npm package

  nativeBuildInputs = [ python3 ];

  meta = {
    description = "Semantic grep for AI agents";
    homepage = "https://github.com/Ryandonofrio3/osgrep";
    license = lib.licenses.asl20;
    mainProgram = "osgrep";
  };
}
