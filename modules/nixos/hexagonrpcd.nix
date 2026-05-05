self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  vanilla-mobile-pkgs = self.packages.${pkgs.stdenv.hostPlatform.system};

  cfg = config.services.hexagonrpcd;
in
{
  options.services.hexagonrpcd = {
    package = lib.mkPackageOption vanilla-mobile-pkgs "hexagonrpc" { };

    adsp-rootpd.enable = lib.mkEnableOption "Server for FastRPC calls from Qualcomm ADSP - RootPD";
    adsp-sensorspd.enable = lib.mkEnableOption "Server for FastRPC calls from Qualcomm ADSP - sensorspd";
    sdsp.enable = lib.mkEnableOption "Server for FastRPC calls from Qualcomm SDSP";
  };

  config = lib.mkIf (cfg.adsp-rootpd.enable || cfg.adsp-sensorspd.enable || cfg.sdsp.enable) {
    # Instead of passing a different firmware directory to hexagonrpc for each device,
    # the firmware will be linked and hexagonrpc will auto-discover the correct
    # firmware based on device tree info.
    environment.pathsToLink = [ "/share/qcom" ];

    users.users.fastrpc = {
      isSystemUser = true;
      group = "fastrpc";
    };
    users.groups.fastrpc = { };
    # Allow access for FastRPC node for FastRPC user/group.
    services.udev.extraRules = ''
      SUBSYSTEM=="misc", KERNEL=="fastrpc-*", OWNER="fastrpc", GROUP="fastrpc", MODE="600", TAG+="systemd"
    '';

    systemd.packages = [ cfg.package ];
    systemd.services.hexagonrpcd-adsp-rootpd.wantedBy = lib.mkIf cfg.adsp-rootpd.enable [
      "multi-user.target"
    ];
    systemd.services.hexagonrpcd-adsp-sensorspd.wantedBy = lib.mkIf cfg.adsp-sensorspd.enable [
      "multi-user.target"
    ];
    systemd.services.hexagonrpcd-sdsp.wantedBy = lib.mkIf cfg.sdsp.enable [
      "multi-user.target"
    ];

  };
}
