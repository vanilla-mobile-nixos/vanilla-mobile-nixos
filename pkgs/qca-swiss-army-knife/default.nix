{
  lib,
  fetchFromGitHub,
  stdenvNoCC,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "qca-swiss-army-knife";
  version = "0-git20220701";

  src = fetchFromGitHub {
    owner = "qca";
    repo = "qca-swiss-army-knife";
    rev = "1b102ba5126bbbdae0efa6f568ac2467392b49f4";
    hash = "sha512-05yMQa0n3mam1HxiiN+hVTsPWOdrUDoCtw5ly3YqKoa3TvExfrdAaZGGprIvz3YaIz1A9sndlzATlRLl1KZ0ug==";
  };

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  nativeBuildInputs = [
    python3
  ];
  installPhase = ''
    mkdir -p "$out/bin"
    find tools/scripts -type f \
      -exec install -Dm755 {} -t "$out/bin" \;
    patchShebangs "$out/bin"

  '';

  meta = {
    description = "Utilities for Qualcomm Atheros wireless driver development";
    homepage = "https://github.com/qca/qca-swiss-army-knife";
    license = lib.licenses.isc;
    platforms = lib.platforms.all;
  };
}
