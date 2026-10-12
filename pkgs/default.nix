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
  fairphone5-firmware = callPackage ./fairphone5-firmware { };
  focal32-firmware = callPackage ./focal32-firmware { };

  alsa-ucm-conf-sdm845 = callPackage ./alsa-ucm-conf-sdm845 { };
  alsa-ucm-conf-sc7280 = callPackage ./alsa-ucm-conf-sc7280 { };

  unudhcpd = callPackage ./unudhcpd { };
  hexagonrpc = callPackage ./hexagonrpc { inherit (pkgs) hexagonrpc; };
  hyprgrass = callPackage ./hyprgrass { inherit (pkgs.hyprlandPlugins) hyprgrass; };
  iio-hyprland = callPackage ./iio-hyprland { };
  pil-squasher = callPackage ./pil-squasher { };
  fairphone5-libcamera-tuning = callPackage ./fairphone5-libcamera-tuning { };
  fp5-fingerprint-tools = callPackage ./fp5-fingerprint-tools { };
  libcamera-fairphone5 = callPackage ./libcamera-fairphone5 { };
  libfprint-focaltech = callPackage ./libfprint-focaltech { };
  mobile-config-firefox = callPackage ./mobile-config-firefox { };
  ssu-sysinfo = callPackage ./ssu-sysinfo { };
  swclock-offset = callPackage ./swclock-offset { };
  usb-moded = callPackage ./usb-moded { };
  usb-moded-notify = callPackage ./usb-moded-notify { };
  q6voiced = callPackage ./q6voiced { };
}
