{
  lib,
  stdenv,
  fetchFromGitLab,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "mobile-config-firefox";
  version = "5.2.0";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "mobile-config-firefox";
    tag = finalAttrs.version;
    hash = "sha256-7kODNqICVGVxjNt7RYseQr0TDjC3L5EJprZTPeJxvMM=";
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
    homepage = "https://gitlab.postmarketos.org/postmarketOS/mobile-config-firefox";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
})
