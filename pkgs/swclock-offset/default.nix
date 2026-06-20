{
  lib,
  stdenv,
  fetchFromGitLab,
  makeWrapper,
  coreutils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "swclock-offset";
  version = "0.3.0";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "swclock-offset";
    rev = finalAttrs.version;
    hash = "sha256-4iVSua0UJuom0QxZNVUHo8lD3Pcke6CoHIozaG9JO3c=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  makeFlags = [
    "prefix=$(out)"
  ];
  installTargets = [
    "bin"
    "systemd"
  ];

  postInstall = ''
    wrapProgram $out/bin/swclock-offset-boot \
        --prefix PATH : ${lib.makeBinPath [ coreutils ]}
    wrapProgram $out/bin/swclock-offset-shutdown \
        --prefix PATH : ${lib.makeBinPath [ coreutils ]}
  '';

  meta = {
    description = "Save/load real-time clock (RTC) offset for devices with a non-writable RTC";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/swclock-offset";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = lib.platforms.linux;
  };
})
