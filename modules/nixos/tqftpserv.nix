self: {
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tqftpserv;
in
{
  options.services.tqftpserv = {
    enable = lib.mkEnableOption "QRTR TFTP service";
    package = lib.mkPackageOption pkgs "tqftpserv" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];
    systemd.services.tqftpserv.wantedBy = [ "multi-user.target" ];
  };
}
