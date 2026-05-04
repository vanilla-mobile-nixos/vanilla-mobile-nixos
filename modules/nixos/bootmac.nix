self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  vanilla-mobile-pkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
  cfg = config.services.bootmac;
in
{
  options.services.bootmac = {
    enable = lib.mkEnableOption "bootmac";
    package = lib.mkPackageOption vanilla-mobile-pkgs "bootmac" { };
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];
    systemd.services.bootmac-bluetooth.wantedBy = [ "bluetooth.target" ];
  };
}
