self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  vanilla-mobile-pkgs = self.packages.${pkgs.stdenv.hostPlatform.system};

  cfg = config.vanilla-mobile.soc.sdm845;
in
{
  options.vanilla-mobile.soc.sdm845 = {
    enable = lib.mkEnableOption "sdm845";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.hostPlatform = "aarch64-linux";

    # Some firmware from `linux-firmware` is required.
    hardware.enableRedistributableFirmware = true;

    boot = {
      kernelPackages = lib.mkForce (pkgs.linuxPackagesFor vanilla-mobile-pkgs.linuxKernels.linux_sdm845);
      kernelParams = [ "console=tty0" ];
      initrd = {
        # disable default modules (some of which dont exist in our kernel).
        includeDefaultModules = false;
        availableKernelModules = [
          "sd_mod"
        ];
        kernelModules = [
          "dm_mod"
        ];
        systemd.tpm2.enable = false;
      };
      blacklistedKernelModules = [
        # Booting will fail if IPA loads before firmware is available.
        # It also might cause holdups on shutdown, but I can't remember
        # for sure if it was this.
        "ipa"
      ];

      loader.efi.canTouchEfiVariables = false;
    };

    # Modem
    services.rmtfs.enable = true;
    services.tqftpserv.enable = true;
    services.msm-modem-uim-selection.enable = true;

    networking.modemmanager.enable = true;

    # To setup a MAC address for Bluetooth.
    services.bootmac.enable = true;

    # These devices don't have a writable RTC.
    services.swclock-offset.enable = true;
  };
}
