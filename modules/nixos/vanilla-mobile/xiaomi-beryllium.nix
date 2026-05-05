self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  vanilla-mobile-pkgs = self.packages.${pkgs.stdenv.hostPlatform.system};

  cfg = config.vanilla-mobile.device.xiaomi-beryllium;
in
{
  options.vanilla-mobile.device.xiaomi-beryllium = {
    enable = lib.mkEnableOption "Xiaomi POCO F1 (xiaomi-beryllium)";
    displayPanel = lib.mkOption {
      type = lib.types.enum [
        "ebbg"
        "tianma"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    warnings =
      if !config.boot.loader.systemd-boot.enable then
        [
          ''
            systemd-boot is disabled. xiaomi-beryllium has currently only
            been configured/tested for systemd-boot.
          ''
        ]
      else
        [ ];

    vanilla-mobile.soc.sdm845.enable = true;

    # Link `/share` into environment for hexagonrpcd.
    environment.systemPackages = [ vanilla-mobile-pkgs.xiaomi-beryllium-firmware ];

    hardware = {
      firmware = lib.mkAfter [ vanilla-mobile-pkgs.xiaomi-beryllium-firmware ];
      deviceTree = {
        enable = true;
        name = "qcom/sdm845-xiaomi-beryllium-${cfg.displayPanel}.dtb";
      };
    };
    boot = {
      kernelParams = [
        # Look for the firmware we add to `extra-firmware`.
        "firmware_class.path=/extra-firmware"
      ];
      initrd = {
        # Based on
        # <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/master/device/community/device-xiaomi-beryllium/modules-initfs.tianma>
        kernelModules = [
          "gpi"
          "i2c_qcom_geni"
          "qcom_smbx"
          #"qcom_fg"
        ]
        ++ (
          if cfg.displayPanel == "ebbg" then
            [
              "focaltech_fts"
              "edt_ft5x06"
            ]
          else
            [
              # "nt36xxx"
              "novatek_nvt_ts"
            ]
        );

        systemd.enable = true;
        systemd.storePaths =
          map
            (fw: {
              source = "${config.hardware.firmware}/lib/firmware/${fw}.zst";
              target = "/extra-firmware/${fw}.zst";
            })
            [
              "qcom/a630_sqe.fw"
              "qcom/a630_gmu.bin"
              "qcom/sdm845/Xiaomi/beryllium/a630_zap.mbn"
            ];
      };
    };

    services.udev.extraRules = ''
      # Accelerometer mount matrix for iio-sensor-proxy. This shouldn't be needed any more
      # due to the Beryllium firmware patch, but `/sys/bus/iio/devices/iio:deviceX/in_accel_mount_matrix`
      # isn't populating.
      SUBSYSTEM=="misc", KERNEL=="fastrpc-*", ENV{ACCEL_MOUNT_MATRIX}+="-1, 0, 0; 0, -1, 0; 0, 0, -1"
    '';
  };

}
