self:
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.swclock-offset;
in
{
  options.services.swclock-offset = {
    enable = lib.mkEnableOption "swclock-offset";
    package = lib.mkPackageOption self.packages "swclock-offset" { };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      packages = [ cfg.package ];
      services = {
        swclock-offset-boot = {
          serviceConfig.RemainAfterExit = true;
          restartIfChanged = false;
        };
        swclock-offset-shutdown = {
          wantedBy = [
            "shutdown.target"
            "reboot.target"
            "halt.target"
          ];
        };
        save-hwclock.enable = false;
      };
      paths.swclock-offset-boot = {
        wantedBy = [ "sysinit.target" ];
        pathConfig.PathExists = [ "/sys/class/rtc/rtc0/since_epoch" ];
      };
    };
  };
}
