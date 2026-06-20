{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchFromGitLab,
  runCommand,
  autoreconfHook,
  pkg-config,
  dbus,
  eudev,
  glib,
  gobject-introspection,
  kmod,
  systemd,
  ssu-sysinfo,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "usb-moded";
  version = "0.86.0+mer69";

  src = fetchFromGitHub {
    owner = "sailfishos";
    repo = "usb-moded";
    tag = "mer/${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-4ocRvcy2Q+jxZesO0G8i5/PUDnT2ZoOYMQk0yBzWuP0=";
  };

  patches = map (patch: "${finalAttrs.passthru.patches}/${patch}") [
    "basename.patch"
    "0001-dyn-config-Add-option-for-running-a-command-on-mode-.patch"
    "0002-worker-generalize-MTP-daemon-to-FunctionFS-daemon.patch"
    "0003-worker-only-check-daemon-running-in-FunctionFS-mode.patch"
    "0004-configfs-Register-NCM-gadget-for-USB-networking.patch"
  ];

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
    dbus
    eudev
    glib
    gobject-introspection
    kmod
    systemd
    ssu-sysinfo
  ];

  configureFlags = [
    # Connman support for usb tethering.
    "--enable-connman"
    # ofono DBUS interface for usb tethering roaming detection.
    "--enable-ofono"
    "--enable-app-sync"
    # Systemd notify interface
    "--enable-systemd"
  ];

  postInstall = ''
      install -Dm644 usb_moded.pc -t $out/lib/pkgconfig/

      install -Dm644 systemd/usb-moded.service -t $out/lib/systemd/system/
      substituteInPlace $out/lib/systemd/system/usb-moded.service \
        --replace-fail "/usr/sbin/usb_moded" "$out/bin/usb_moded"

    	install -Dm644 debian/usb_moded.conf -t $out/share/dbus-1/system.d/
  '';

  passthru.patches =
    runCommand "usb-moded-patches"
      {
        version = "0-unstable-2025-04-14";

        src = fetchFromGitLab {
          domain = "gitlab.postmarketos.org";
          owner = "postmarketOS";
          repo = "pmaports";
          rev = "97d87482ba52b87c2f01827cd64731996d7ffbac";
          sparseCheckout = [ "temp/usb-moded" ];
          hash = "sha256-PhPpIzOPG2Puk2WP7aI6t8FX1ivXiAt+pRl70/UrGQg=";
        };

        meta = {
          license = lib.licenses.gpl3Only;
          platforms = lib.platforms.all;
        };
      }
      ''
        install -D $src/temp/usb-moded/*.patch -t $out
      '';

  meta = {
    description = "Daemon that activates certain USB profiles based on the USB cable connection status";
    homepag = "https://github.com/sailfishos/usb-moded";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = lib.platforms.linux;
  };
})
