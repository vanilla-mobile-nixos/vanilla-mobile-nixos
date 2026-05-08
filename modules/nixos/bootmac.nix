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

    bluetooth.enable = lib.mkEnableOption "bluetooth";
    wifi.enable = lib.mkEnableOption "wifi";
  };

  config = lib.mkIf cfg.enable {
    systemd.packages = [ cfg.package ];
    services.udev.packages = [
      (lib.mkIf cfg.bluetooth.enable (
        pkgs.runCommandLocal "bootmac-bluetooth-udev" { } ''
          install -D ${cfg.package}/lib/udev/rules.d/90-bootmac-bluetooth.rules \
            -t $out/lib/udev/rules.d/
        ''
      ))
      (lib.mkIf cfg.wifi.enable (
        pkgs.runCommandLocal "bootmac-wifi-udev" { } ''
          install -D ${cfg.package}/lib/udev/rules.d/90-bootmac-wifi.rules \
            -t $out/lib/udev/rules.d
        ''
      ))
    ];
  };
}
