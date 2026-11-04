{
  lib,
  stdenv,
  fetchFromGitLab,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mobile-config-firefox";
  version = "5.5.2";

  src = fetchFromGitLab {
    domain = "gitlab.nura.eco";
    owner = "nura";
    repo = "mobile-config-firefox";
    tag = finalAttrs.version;
    hash = "sha256-XxOLkTyEYTfdK55dsfZOL8GguHv/6JdmAv2xwcoaxDY=";
  };

  dontBuild = true;

  makeFlags = [
    "DESTDIR=$(out)"
    "FIREFOX_DIR=/lib/firefox"
    "MCF_DIR=/lib/mobile-config-firefox"
  ];

  postInstall = ''
    substituteInPlace $out/lib/firefox/mobile-config-autoconfig.js \
      --replace-fail "/usr/lib/mobile-config-firefox" "$out/lib/mobile-config-firefox"
  '';

  meta = {
    description = "Firefox tweaks for mobile and privacy";
    homepage = "https://gitlab.nura.eco/nura/mobile-config-firefox";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = lib.platforms.all;
  };
})
