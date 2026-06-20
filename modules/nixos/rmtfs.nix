self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rmtfs;
in
{
  options.services.rmtfs = {
    enable = lib.mkEnableOption "Qualcomm remotefs service";
    package = lib.mkPackageOption pkgs "rmtfs" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];
    systemd.services.rmtfs.wantedBy = [ "multi-user.target" ];

    # I'm not sure what uses this, but PostMarketOS includes it.
    services.udev.extraRules = ''
      SUBSYSTEM=="uio", ATTR{name}=="rmtfs", SYMLINK+="qcom_rmtfs_uio1"
    '';
  };

  meta.maintainers = [ lib.maintainers.junestepp ];
}
