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

    # A crude way of preventing the devices from running out of RAM or generally
    # freezing up while building their configurations.
    nix.settings.max-jobs = lib.mkDefault 2;

    # These devices have very limited RAM.
    zramSwap.enable = lib.mkDefault true;

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
        # IPA also causes issues during shutdown, so it is not loaded
        # after boot.
        "ipa"
      ];

      loader = {
        efi.canTouchEfiVariables = false;

        # Currently only tested on systemd-boot.
        grub.enable = lib.mkDefault false;
        systemd-boot.enable = lib.mkDefault true;
      };
    };

    # Modem
    services.rmtfs.enable = true;
    services.tqftpserv.enable = true;
    services.msm-modem-uim-selection.enable = true;

    networking.modemmanager.enable = true;

    # Setup Bluetooth interface MAC address.
    services.bootmac = {
      enable = true;
      bluetooth.enable = true;
    };

    # These devices don't have a writable RTC.
    services.swclock-offset.enable = true;

    # Sensors
    services.hexagonrpcd.sdsp.enable = true;
    hardware.sensor.iio.enable = true;
  };
}
