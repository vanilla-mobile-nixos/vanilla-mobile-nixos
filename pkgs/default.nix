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

  alsa-ucm-conf-sdm845 = callPackage ./alsa-ucm-conf-sdm845 { };

  bootmac = callPackage ./bootmac { };
  hexagonrpc = callPackage ./hexagonrpc { inherit (pkgs) hexagonrpc; };
  msm-modem = callPackage ./msm-modem { };
  swclock-offset = callPackage ./swclock-offset { };
  q6voiced = callPackage ./q6voiced { };
}
