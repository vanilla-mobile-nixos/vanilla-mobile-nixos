{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "unudhcpd";
  version = "0.2.1";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "unudhcpd";
    rev = finalAttrs.version;
    hash = "sha256-k/V3Rq8oSSPl4vaEz2EsHiRujXa/ErJoF0lq5ronGMA=";
  };

  nativeBuildInputs = [
    meson
    ninja
  ];

  meta = {
    descrption = "Basic DHCP server that only issues 1 IP address";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/unudhcpd";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    mainProgram = "unudhcpd";
  };
})
