{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.soc.sdm845;
in
{
  options.vanilla-mobile.soc.qualcomm = {
    enable = lib.mkEnableOption "Qualcomm";

    audio.enable = lib.mkEnableOption "audio";
    modem.enable = lib.mkEnableOption "modem";
    sensors.enable = lib.mkEnableOption "sensors";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        vanilla-mobile = {
          enable = true;
          soc.qualcomm = {
            audio.enable = lib.mkDefault true;
            modem.enable = lib.mkDefault true;
            sensors.enable = lib.mkDefault true;
          };
        };

        nixpkgs.hostPlatform = "aarch64-linux";

        # Some firmware from `linux-firmware` is required.
        hardware.enableRedistributableFirmware = true;
        # Link firmware `/share` into environment for hexagonrpcd.
        environment.systemPackages = lib.mkIf (config.vanilla-mobile.deviceInfo.firmware != null) [
          config.vanilla-mobile.deviceInfo.firmware
        ];

        vanilla-mobile.uboot.enable = true;

        hardware.bluetooth.enable = lib.mkDefault true;
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
        hardware.sensor.iio.enable = true;
      })
    ]
  );

  meta.maintainers = [ lib.maintainers.junestepp ];
}
