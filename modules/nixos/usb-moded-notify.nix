self:
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.usb-moded-notify;
in
{
  options.services.usb-moded-notify = {
    enable = lib.mkEnableOption "usb-moded-notify";
    package = lib.mkPackageOption self.packages "usb-moded-notify" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];

    systemd.user.services.usb-moded-notify = {
      wantedBy = [ "graphical-session.target" ];
    };
  };
}
