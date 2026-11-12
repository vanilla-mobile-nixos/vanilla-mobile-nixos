self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.soc.sdm845;
in
{
  imports = [
    (import ./xiaomi-beryllium.nix self)
    (import ./oneplus-enchilada.nix self)
    (import ./oneplus-fajita.nix self)
  ];

  options.vanilla-mobile.soc.sdm845 = {
    enable = lib.mkEnableOption "sdm845";

    audio.enable = lib.mkEnableOption "audio";
    modem.enable = lib.mkEnableOption "modem";
    sensors.enable = lib.mkEnableOption "sensors";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        vanilla-mobile.soc = {
          qualcomm.enable = true;
          sdm845 = {
            audio.enable = lib.mkDefault true;
            modem.enable = lib.mkDefault true;
            sensors.enable = lib.mkDefault true;
          };
        };

        # A crude way of preventing the devices from running out of RAM or generally
        # freezing up while building their configurations.
        nix.settings.max-jobs = lib.mkDefault 2;

        # These devices have very limited RAM.
        zramSwap.enable = lib.mkDefault true;

        boot = {
          kernelPackages = lib.mkForce (
            config.vanilla-mobile.installer.crossPkgs.linuxPackagesFor config.vanilla-mobile.installer.vanillaMobileCrossPkgs.linuxKernels.linux_sdm845
          );

          blacklistedKernelModules = [
            # Causes boot lockup. Can be modprobed later.
            "ipa"
          ];
          kernelParams = [
            "console=tty0"
            # Improves boot with `ipa` kernel module. Also, helps security.
            # "init_on_alloc=1"
          ];
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
        };
      }
      # Audio
      (lib.mkIf cfg.audio.enable {
        vanilla-mobile = {
          soc.qualcomm.audio.enable = true;
          alsa-ucm-conf = {
            enable = true;
            package = self.packages.alsa-ucm-conf-sdm845;
          };
        };
      })
      # Modem
      (lib.mkIf cfg.modem.enable {
        vanilla-mobile.soc.qualcomm.modem.enable = true;
      })
      # Sensors
      (lib.mkIf cfg.sensors.enable {
        vanilla-mobile.soc.qualcomm.sensors.enable = true;
        services.hexagonrpcd.sdsp.enable = true;
      })
    ]
  );

  meta.maintainers = [ lib.maintainers.junestepp ];
}
