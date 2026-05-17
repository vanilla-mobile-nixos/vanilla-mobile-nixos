self:
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.q6voiced;
in
{
  options.services.q6voiced = {
    enable = lib.mkEnableOption "q6voice call audio routing";
    package = lib.mkPackageOption self.packages "q6voiced" { };

    settings = {
      q6voice_card = lib.mkOption {
        type = lib.types.int;
        example = 0;
        description = "Modem audio card as given by `alsactl info`.";
      };
      q6voice_device = lib.mkOption {
        type = lib.types.int;
        example = 4;
        description = "Modem audio device as given by `alsactl info`.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];

    systemd.services.q6voiced = {
      wantedBy = [ "multi-user.target" ];

      # Don't depend on a settings file.
      unitConfig.ConditionPathExists = [ "" ];
      serviceConfig.EnvironmentFile = [ "" ];

      environment = lib.mapAttrs (name: value: toString value) cfg.settings;
    };
  };
}
