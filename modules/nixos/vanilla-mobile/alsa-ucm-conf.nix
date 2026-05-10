{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.alsa-ucm-conf;

  alsa-ucm-conf =
    if cfg.mergeWithDefault then
      pkgs.symlinkJoin {
        pname = "${cfg.package.pname}-merged";
        inherit (cfg.package) version;

        paths = [
          pkgs.alsa-ucm-conf
          cfg.package
        ];
      }
    else
      cfg.package;
in
{
  options.vanilla-mobile.alsa-ucm-conf = {
    enable = lib.mkEnableOption "Custom alsa-ucm-conf";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Custom alsa-ucm-conf package to use.";
    };

    mergeWithDefault = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Merge with default `alsa-ucm-conf`.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.variables.ALSA_CONFIG_UCM2 = "${alsa-ucm-conf}/share/alsa/ucm2";
      }
      # Pipewire user services:
      (lib.mkIf (config.services.pipewire.enable && !config.services.pipewire.systemWide) {
        systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
        systemd.user.services.pipewire-pulse.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
        systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
      })
      # Pipewire system services:
      (lib.mkIf (config.services.pipewire.enable && config.services.pipewire.systemWide) {
        systemd.services.pipewire.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
        systemd.services.pipewire-pulse.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
        systemd.services.wireplumber.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
      })
      # PulseAudio use service:
      (lib.mkIf (config.services.pulseaudio.enable && !config.services.pulseaudio.systemWide) {
        systemd.user.services.pulseaudio.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
      })
      # PulseAudio system service:
      (lib.mkIf (config.services.pulseaudio.enable && config.services.pulseaudio.systemWide) {
        systemd.services.pulseaudio.environment.ALSA_CONFIG_UCM2 =
          config.environment.variables.ALSA_CONFIG_UCM2;
      })
    ]
  );
}
