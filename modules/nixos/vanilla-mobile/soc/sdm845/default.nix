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
  imports = [
    (import ./xiaomi-beryllium.nix self)
  ];

  options.vanilla-mobile.soc.sdm845 = {
    enable = lib.mkEnableOption "sdm845";
    modem.enable = lib.mkEnableOption "modem";
    sensors.enable = lib.mkEnableOption "sensors";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        vanilla-mobile.soc.sdm845 = {
          modem.enable = lib.mkDefault true;
          sensors.enable = lib.mkDefault true;
        };

        nixpkgs.hostPlatform = "aarch64-linux";

        # A crude way of preventing the devices from running out of RAM or generally
        # freezing up while building their configurations.
        nix.settings.max-jobs = lib.mkDefault 2;

        # These devices have very limited RAM.
        zramSwap.enable = lib.mkDefault true;

        # Some firmware from `linux-firmware` is required.
        hardware.enableRedistributableFirmware = true;

        # Link firmware `/share` into environment for hexagonrpcd.
        environment.systemPackages = [ config.vanilla-mobile.deviceInfo.firmware ];

        vanilla-mobile.uboot.enable = true;
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
        };

        # Setup Bluetooth interface MAC address.
        services.bootmac = {
          enable = true;
          bluetooth.enable = true;
        };

        # These devices don't have a writable RTC.
        services.swclock-offset.enable = true;
      }
      # Modem
      (lib.mkIf cfg.modem.enable {
        services.rmtfs.enable = true;
        services.tqftpserv.enable = true;
        services.msm-modem-uim-selection.enable = true;

        networking.modemmanager.enable = true;
      })
      # Sensors
      (lib.mkIf cfg.sensors.enable {
        services.hexagonrpcd.sdsp.enable = true;
        hardware.sensor.iio.enable = true;
      })
    ]
  );
}
