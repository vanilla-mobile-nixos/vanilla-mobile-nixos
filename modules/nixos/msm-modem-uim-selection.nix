self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.msm-modem-uim-selection;
in
{
  options.services.msm-modem-uim-selection = {
    enable = lib.mkEnableOption "Qualcomm MSM modems UIM selection service";
    package = lib.mkPackageOption self.packages "msm-modem" { };
    simWaitTime = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      example = 10;
      description = ''
        How long to wait for SIM card to appear after starting the modem.
        The wait is 4 seconds by default. You may need to increase this for
        some modems. You can also set it to 0 if you don't have a SIM card.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];
    systemd.services.msm-modem-uim-selection = {
      wantedBy = [ "multi-user.target" ];

      environment.SIM_WAIT_TIME = if cfg.simWaitTime == null then null else toString cfg.simWaitTime;

      serviceConfig.RemainAfterExit = true;
    };
  };

  meta.maintainers = [ lib.maintainers.junestepp ];
}
