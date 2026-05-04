{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
  makeWrapper,
  gawk,
  bluez,
  util-linux,
  gnugrep,
  coreutils,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  name = "bootmac";
  version = "0.6.0";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "bootmac";
    rev = "v${finalAttrs.version}";
    hash = "sha256-P6PllD7ploQiLqyksmBkYe44badWL2LuCSNPhGw32xo=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    install bootmac $out/bin/bootmac
    wrapProgram $out/bin/bootmac \
      --prefix PATH : ${
        lib.makeBinPath [
          gawk
          bluez
          util-linux
          gnugrep
          coreutils
        ]
      }

    mkdir -p $out/lib/systemd/system
    substitute bootmac-bluetooth.service \
      $out/lib/systemd/system/bootmac-bluetooth.service \
      --replace-fail /usr/bin/bootmac $out/bin/bootmac
  '';

  meta = {
    description = "Configure the MAC addresses of WLAN and Bluetooth interfaces at boot";
    mainProgram = "bootmac";
    license = lib.licenses.gpl3;
    platforms = bluez.meta.platforms;
  };
})
