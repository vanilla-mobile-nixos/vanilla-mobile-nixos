self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile;
in
{
  imports = (lib.remove self.nixosModules.vanilla-mobile (lib.attrValues self.nixosModules)) ++ [
    (import ./soc self)
    ./alsa-ucm-conf.nix
    ./deviceInfo.nix
    (import ./disko.nix self)
    ./uboot.nix
  ];

  hardware = {
    firmware = lib.mkIf (cfg.deviceInfo.firmware != null) (
      lib.mkAfter [
        cfg.deviceInfo.firmware
      ]
    );
    deviceTree = lib.mkIf (cfg.deviceInfo.dtb != null) {
      enable = true;
      name = cfg.deviceInfo.dtb;
    };
  };

  # Allow using the power button to toggle Plymouth splash.
  boot.plymouth.extraConfig = ''
    XkbExtraEscButton=0x1008ff2a  # XKB_KEY_XF86PowerOff
  '';

  # Enable Modem Manager quick suspend and resume support. Without it,
  # Modem Manager will crash and not resume properly after a suspend.
  # See <https://gitlab.freedesktop.org/mobile-broadband/ModemManager/-/work_items/1039>
  systemd.services.ModemManager.serviceConfig.ExecStart =
    lib.mkIf config.networking.modemmanager.enable
      [
        "" # Ignore original ExecStart.
        "${pkgs.modemmanager}/bin/ModemManager --test-quick-suspend-resume"
      ];

  # People typically have single presses toggle the display/suspend, not a full poweroff.
  services.logind.settings = {
    Login.HandlePowerKey = lib.mkDefault "ignore";
    Login.HandlePowerKeyLongPress = lib.mkDefault "poweroff";
  };

  # Enable proximity and accel sensors in iio-sensor-proxy.
  # See <https://gitlab.freedesktop.org/hadess/iio-sensor-proxy/-/merge_requests/409>.
  services.udev.extraRules = ''
    ACTION=="remove", GOTO="iio_sensor_proxy_end"

    SUBSYSTEM=="misc", KERNEL=="fastrpc-adsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity"
    SUBSYSTEM=="misc", KERNEL=="fastrpc-sdsp*", ENV{IIO_SENSOR_PROXY_TYPE}+="ssc-accel ssc-proximity"

    LABEL="iio_sensor_proxy_end"
  '';
  # Reduce iio-sensor-proxy timeout to be killed until patch is upstream.
  # See https://gitlab.freedesktop.org/hadess/iio-sensor-proxy/-/merge_requests/410
  systemd.services.iio-sensor-proxy.serviceConfig.TimeoutStopSec = 3;
}
