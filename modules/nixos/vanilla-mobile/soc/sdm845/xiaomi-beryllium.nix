self:
{
  config,
  lib,
  ...
}:
let
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

    vanilla-mobile = {
      deviceInfo = {
        name = "Xiaomi Poco F1";
        codename = "xiaomi-beryllium";
        manufacturer = "Xiaomi";
        dtb = "qcom/sdm845-xiaomi-beryllium-${cfg.displayPanel}.dtb";
        imageSectorSize = 4096;
        firmware = self.packages.xiaomi-beryllium-firmware;
        uboot = self.packages.ubootPackages."xiaomi-beryllium-${cfg.displayPanel}-boot-image";
      };
      soc.sdm845.enable = true;
    };

    boot = {
      kernelParams = [
        # Look for the firmware we add to `extra-firmware`.
        "firmware_class.path=/extra-firmware"
      ];
      initrd = {
        # Based on
        # <https://gitlab.nura.eco/nura/pmaports/-/blob/master/device/community/device-xiaomi-beryllium/modules-initfs.tianma>
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

        systemd.storePaths =
          map
            (fw: {
              source = "${config.hardware.firmware}/lib/firmware/${fw}.zst";
              target = "/extra-firmware/${fw}.zst";
            })
            [
              # Good reference: <https://salsa.debian.org/DebianOnMobile-team/qcom-phone-utils/-/blob/debian/latest/initramfs-tools/hooks/qcom-firmware>.
              # Including these in initramfs isn't strictly necessary. The GPU ones
              # remove an error, and the others *might* help when using the `ipa` kernel
              # module.
              "qcom/sdm845/Xiaomi/beryllium/adsp.mbn"
              "qcom/sdm845/Xiaomi/beryllium/cdsp.mbn"
              "qcom/sdm845/Xiaomi/beryllium/ipa_fws.mbn"

              "qcom/sdm845/Xiaomi/beryllium/a630_zap.mbn"
              "qcom/sdm845/Xiaomi/beryllium/slpi.mbn"
              "ath10k/WCN3990/hw1.0/board-2.bin"
              "qca/crbtfw21.tlv"
              "qca/crnv21.bin"

              "qcom/a630_sqe.fw"
              "qcom/a630_gmu.bin"
            ];
      };
    };

    services.q6voiced.settings = {
      q6voice_card = 0;
      q6voice_device = 4;
    };
  };

  meta.maintainers = [ lib.maintainers.junestepp ];
}
