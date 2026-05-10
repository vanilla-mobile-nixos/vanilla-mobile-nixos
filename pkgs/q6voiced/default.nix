{
  lib,
  stdenv,
  fetchFromGitLab,
  pkg-config,
  meson,
  ninja,
  alsa-lib,
  dbus,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "q6voiced";
  version = "0.2.1";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "q6voiced";
    tag = finalAttrs.version;
    hash = "sha256-f8NigGVR9O7ln/7yXc+CbhZ6WLy91zri6ytzj6PQYAQ=";
  };

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
  ];

  buildInputs = [
    alsa-lib
    dbus
  ];

  meta = {
    description = "Userspace QDSP6 voice driver daemon listing on oFono/ModemManager";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/q6voiced";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
