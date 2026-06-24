self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.iio-hyprland;
in
{
  options.services.iio-hyprland = {
    enable = lib.mkEnableOption "iio-hyprland auto screen rotation";
    package = lib.mkPackageOption self.packages "iio-hyprland" { };

    output = lib.mkOption {
      type = lib.types.str;
      default = "eDP-1";
      example = "DSI-1";
      description = "Output to rotate.";
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "--flip-bottom-up" ];
      description = ''
        Extra command line args to pass to iio-hyprland.
        See <https://github.com/JeanSchoeller/iio-hyprland/#running>
        for an explanation of what arguments are available.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          (
            config.wayland.windowManager.hyprland.enable
            && config.wayland.windowManager.hyprland.configType == "lua"
          )
          || (!config.wayland.windowManager.hyprland.enable)
          || cfg.package != self.packages.iio-hyprland;
        message = ''
          This `iio-hyprland` package only supports Hyprland Lua configs.
          hyprlang configs are deprecated.
        '';
      }
    ];

    systemd.user.services.iio-hyprland = {
      Unit = {
        Description = "Rotate Hyrpland output based on sensor data";
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 60 * 3;
        StartLimitBurst = 99999;
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${lib.getExe cfg.package} ${cfg.output} ${lib.concatStringsSep " " cfg.extraArgs}";
        Restart = "on-failure";
        RestartSec = 1;
        Slice = "background-graphical.slice";
      };
    };
  };

  meta.maintainers = [ lib.maintainers.junestepp ];
}
