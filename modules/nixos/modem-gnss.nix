self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.modem-gnss;
in
{
  options.services.modem-gnss = {
    enable = lib.mkEnableOption "Qualcomm modem GNSS setup service";
    package = lib.mkPackageOption pkgs "libqmi" { };
  };

  config = lib.mkIf cfg.enable {
    # From pmaports soc-qcom: the modem emits no standard NMEA until told to.
    systemd.services.modem-gnss = {
      description = "Qualcomm GNSS Modem Setup";
      wantedBy = [ "multi-user.target" ];
      after = [ "ModemManager.service" ];
      requires = [ "ModemManager.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          "${lib.getExe' cfg.package "qmicli"} -d qrtr://0 --loc-set-engine-lock=mt"
          "${lib.getExe' cfg.package "qmicli"} -d qrtr://0 --loc-set-nmea-types=all"
        ];
        # The location service can come up later than ModemManager.
        Restart = "on-failure";
        RestartSec = "30s";
        StartLimitBurst = 10;
      };
    };
  };
}
