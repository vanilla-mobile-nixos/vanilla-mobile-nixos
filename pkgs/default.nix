pkgs: self:
let
  inherit (pkgs) lib;
  inherit (self) callPackage;
  inherit (lib) recurseIntoAttrs;
in
{
  linuxKernels = recurseIntoAttrs (callPackage ./linux-kernel { });

  dtbtool-exynos = callPackage ./dtbtool-exynos { };
  ubootUtils = recurseIntoAttrs (callPackage ./uboot/utils.nix { });
  ubootPackages = recurseIntoAttrs (callPackage ./uboot { });

  # Firmware
  xiaomi-beryllium-firmware = callPackage ./xiaomi-beryllium-firmware { };
  oneplus-sdm845-firmware = callPackage ./oneplus-sdm845-firmware { };
  fairphone-fp5-firmware = callPackage ./fairphone-fp5-firmware { };
  ftharness = callPackage ./ftharness { };
  ffsupplicant = callPackage ./ffsupplicant { };
  libfprint-focaltech = callPackage ./libfprint { inherit (pkgs) libfprint; };
  pil-squasher = callPackage ./pil-squasher { };

  alsa-ucm-conf-sdm845 = callPackage ./alsa-ucm-conf-sdm845 { };

  bootmac = callPackage ./bootmac { };
  unudhcpd = callPackage ./unudhcpd { };
  hexagonrpc = callPackage ./hexagonrpc { inherit (pkgs) hexagonrpc; };
  hyprgrass = callPackage ./hyprgrass { inherit (pkgs.hyprlandPlugins) hyprgrass; };
  iio-hyprland = callPackage ./iio-hyprland { };
  mobile-config-firefox = callPackage ./mobile-config-firefox { };
  msm-modem = callPackage ./msm-modem { };
  pd-mapper = callPackage ./pd-mapper { };
  ssu-sysinfo = callPackage ./ssu-sysinfo { };
  swclock-offset = callPackage ./swclock-offset { };
  usb-moded = callPackage ./usb-moded { };
  usb-moded-notify = callPackage ./usb-moded-notify { };
  q6voiced = callPackage ./q6voiced { };
}
