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
        vanilla-mobile.soc.sdm845 = {
          audio.enable = lib.mkDefault true;
          modem.enable = lib.mkDefault true;
          sensors.enable = lib.mkDefault true;
        };

        vanilla-mobile.enable = true;

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

        # Setup Bluetooth interface MAC address.
        services.bootmac = {
          enable = true;
          bluetooth.enable = true;
        };

        # These devices don't have a writable RTC.
        services.swclock-offset.enable = true;
      }
      # Audio
      (lib.mkIf cfg.audio.enable {
        vanilla-mobile.alsa-ucm-conf = {
          enable = true;
          package = self.packages.alsa-ucm-conf-sdm845;
        };

        # Only tested with PipeWire.
        services.pipewire = {
          enable = lib.mkDefault true;
          alsa.enable = lib.mkDefault true;
          pulse.enable = lib.mkDefault true;
        };
        security.rtkit.enable = lib.mkDefault true;

        # See <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/main/device/community/soc-qcom/51-qcom.conf>.
        services.pipewire.wireplumber.extraConfig."51-qcom" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                {
                  # Matches all sources.
                  "node.name" = "~alsa_input.*";
                }
                {
                  # Matches all sinks.
                  "node.name" = "~alsa_output.*";
                }
              ];
              actions = {
                update-props = {
                  "audio.format" = "S16LE";
                  "audio.rate" = 48000;
                  "api.alsa.period-size" = 4096;
                  "api.alsa.period-num" = 6;
                  "api.alsa.headroom" = 512;
                  # session.suspend-timeout-seconds = 0
                  # dither.method = "wannamaker3", # add dither of desired shape
                  # dither.noise = 2, # add additional bits of noise
                };
              };
            }
          ];
        };

        services.q6voiced.enable = true;
      })
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

  meta.maintainers = [ lib.maintainers.junestepp ];
}
