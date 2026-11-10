self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.device.oneplus-kebab;
in
{
  options.vanilla-mobile.device.oneplus-kebab = {
    enable = lib.mkEnableOption "Oneplus 8T (oneplus-kebab)";
  };

  config = lib.mkIf cfg.enable {
    warnings =
      if !config.boot.loader.systemd-boot.enable then
        [
          ''
            systemd-boot is disabled. oneplus-kebab has currently only
            been configured/tested for systemd-boot.
          ''
        ]
      else
        [ ];

    vanilla-mobile = {
      deviceInfo = {
        name = "Oneplus 8T";
        codename = "oneplus-kebab";
        manufacturer = "Oneplus";
        dtb = "qcom/sm8250-oneplus-kebab.dtb";
        imageSectorSize = 4096;
        firmware = self.packages.oneplus-kebab-firmware;
        uboot = self.packages.ubootPackages.oneplus-kebab-boot-image;
      };
      soc.sm8250.enable = true;
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
        ];

        systemd.storePaths =
          map
            (fw: {
              source = "${config.hardware.firmware}/lib/firmware/${fw}.zst";
              target = "/extra-firmware/${fw}.zst";
            })
            [
              "qcom/sm8250/OnePlus/kebab/adsp.mbn"
              "qcom/sm8250/OnePlus/kebab/cdsp.mbn"
              "qcom/sm8250/OnePlus/kebab/a650_zap.mbn"
              "qcom/sm8250/OnePlus/kebab/ipa_fws.mbn"
              "qcom/sm8250/OnePlus/kebab/ipa_uc.mbn"
              "qcom/sm8250/OnePlus/kebab/slpi.mbn"
              "qcom/sm8250/OnePlus/kebab/venus.mbn"
              "ath11k/QCA6390/hw2.0/board2.bin"
              "ath11k/QCA6390/hw2.0/board-2.bin"
              "ath11k/QCA6390/hw2.0/amss.bin"
              "ath11k/QCA6390/hw2.0/m3.bin"

              "qca/NOTICE.txt"
              "qca/crbtfw21.tlv"
              "qca/crbtfw32.tlv"
              "qca/crnv21.bin"
              "qca/crnv32.bin"
              "qca/crnv32u.bin"
              "qca/hpbtfw21.tlv"
              "qca/hpnv21.301"
              "qca/hpnv21.302"
              "qca/hpnv21.bin"
              "qca/hpnv21g.301"
              "qca/hpnv21g.302"
              "qca/hpnv21g.bin"
              "qca/htbtfw10.tlv"
              "qca/htbtfw20.tlv"
              "qca/htbtfw20.ver"
              "qca/htnv10.bin"
              "qca/htnv20.bin"
              "qca/msbtfw11.mbn"
              "qca/msbtfw11.tlv"
              "qca/msnv11.bin"
              "qca/nvm_00130300.bin"
              "qca/nvm_00130302.bin"
              "qca/nvm_00230302.bin"
              "qca/nvm_00440302.bin"
              "qca/nvm_00440302_eu.bin"
              "qca/nvm_00440302_i2s_eu.bin"
              "qca/nvm_usb_00000200.bin"
              "qca/nvm_usb_00000201.bin"
              "qca/nvm_usb_00000300.bin"
              "qca/nvm_usb_00000302.bin"
              "qca/nvm_usb_00000302_eu.bin"
              "qca/nvm_usb_00130200.bin"
              "qca/nvm_usb_00130200_0104.bin"
              "qca/nvm_usb_00130200_0105.bin"
              "qca/nvm_usb_00130200_0106.bin"
              "qca/nvm_usb_00130200_0107.bin"
              "qca/nvm_usb_00130200_0109.bin"
              "qca/nvm_usb_00130200_0110.bin"
              "qca/nvm_usb_00130201.bin"
              "qca/nvm_usb_00130201_010a.bin"
              "qca/nvm_usb_00130201_010b.bin"
              "qca/nvm_usb_00130201_0303.bin"
              "qca/nvm_usb_00130201_gf.bin"
              "qca/nvm_usb_00130201_gf_010a.bin"
              "qca/nvm_usb_00130201_gf_010b.bin"
              "qca/nvm_usb_00130201_gf_0303.bin"
              "qca/nvm_usb_00190200.bin"
              "qca/rampatch_00130300.bin"
              "qca/rampatch_00130302.bin"
              "qca/rampatch_00230302.bin"
              "qca/rampatch_00440302.bin"
              "qca/rampatch_usb_00000200.bin"
              "qca/rampatch_usb_00000201.bin"
              "qca/rampatch_usb_00000300.bin"
              "qca/rampatch_usb_00000302.bin"
              "qca/rampatch_usb_00130200.bin"
              "qca/rampatch_usb_00130201.bin"
              "qca/rampatch_usb_00190200.bin"

            ];
      };
    };

    services.q6voiced.settings = {
      q6voice_card = 0;
      q6voice_device = 4;
    };
  };

  meta.maintainers = [ lib.maintainers.jedugsem ];
}
