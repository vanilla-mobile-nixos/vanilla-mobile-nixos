self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.soc.sc7280;
in
{
  imports = [
    (import ./fairphone5.nix self)
  ];

  options.vanilla-mobile.soc.sc7280 = {
    enable = lib.mkEnableOption "sc7280";

    audio.enable = lib.mkEnableOption "audio";
    modem.enable = lib.mkEnableOption "modem";
    sensors.enable = lib.mkEnableOption "sensors";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        vanilla-mobile.soc.sc7280 = {
          audio.enable = lib.mkDefault true;
          modem.enable = lib.mkDefault true;
          sensors.enable = lib.mkDefault true;
        };

        vanilla-mobile.enable = true;

        nixpkgs.hostPlatform = "aarch64-linux";

        # A crude way of preventing the devices from running out of RAM or generally
        # freezing up while building their configurations.
        nix.settings.max-jobs = lib.mkDefault 2;

        zramSwap.enable = lib.mkDefault true;

        # Some firmware from `linux-firmware` is required.
        hardware.enableRedistributableFirmware = true;
        # The remoteprocs can't load compressed firmware.
        hardware.firmwareCompression = "none";

        # Link firmware `/share` into environment for hexagonrpcd.
        environment.systemPackages = [ config.vanilla-mobile.deviceInfo.firmware ];

        vanilla-mobile.uboot.enable = true;
        # The kernel is built as an EFI zboot image.
        system.boot.loader.kernelFile = "vmlinuz.efi";
        boot = {
          kernelPackages = lib.mkForce (
            config.vanilla-mobile.installer.crossPkgs.linuxPackagesFor config.vanilla-mobile.installer.vanillaMobileCrossPkgs.linuxKernels.linux_sc7280
          );

          kernelParams = [
            "console=tty0"
          ];
          initrd = {
            # disable default modules (some of which dont exist in our kernel).
            includeDefaultModules = false;
            # The kernel lacks `CONFIG_RD_ZSTD`.
            compressor = "gzip";
            # The LUKS and unl0kr modules list ones the kernel doesn't have
            # (e.g. `i2c-hid-acpi` needs ACPI).
            allowMissingModules = true;

            systemd.enable = true;
            systemd.tpm2.enable = false;
          };
        };

        hardware.bluetooth.enable = lib.mkDefault true;
        # Setup Bluetooth and WiFi interface MAC addresses.
        services.bootmac = {
          enable = true;
          bluetooth.enable = true;
          wifi.enable = true;
        };
      }
      # Audio
      (lib.mkIf cfg.audio.enable {
        vanilla-mobile.alsa-ucm-conf = {
          enable = true;
          package = self.packages.alsa-ucm-conf-sc7280;
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
                };
              };
            }
          ];
        };
      })
      # Modem
      (lib.mkIf cfg.modem.enable {
        services.rmtfs.enable = true;
        services.tqftpserv.enable = true;
        services.msm-modem-uim-selection.enable = true;
        services.modem-gnss.enable = true;

        networking.modemmanager.enable = true;
      })
      # Sensors
      (lib.mkIf cfg.sensors.enable {
        services.hexagonrpcd.adsp-sensorspd.enable = true;
        hardware.sensor.iio.enable = true;

        # iio-sensor-proxy exits if it starts before the ADSP has registered
        # the sensors.
        systemd.services.iio-sensor-proxy = {
          after = [ "hexagonrpcd-adsp-sensorspd.service" ];
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            Restart = "always";
            RestartSec = 5;
          };
        };
      })
    ]
  );

  meta.maintainers = [ lib.maintainers.marcusramberg ];
}
