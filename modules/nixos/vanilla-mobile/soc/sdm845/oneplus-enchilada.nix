self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.device.oneplus-enchilada;
in
{
  options.vanilla-mobile.device.oneplus-enchilada = {
    enable = lib.mkEnableOption "OnePlus 6 (oneplus-enchilada)";
  };

  config = lib.mkIf cfg.enable {
    warnings =
      if !config.boot.loader.systemd-boot.enable then
        [
          ''
            systemd-boot is disabled. oneplus-enchilada has currently only
            been configured for systemd-boot.
          ''
        ]
      else
        [ ];

    vanilla-mobile = {
      deviceInfo = {
        name = "OnePlus 6";
        codename = "oneplus-enchilada";
        manufacturer = "OnePlus";
        dtb = "qcom/sdm845-oneplus-enchilada.dtb";
        imageSectorSize = 4096;
        firmware = self.packages.oneplus-sdm845-firmware;
        uboot = self.packages.ubootPackages.oneplus-enchilada-boot-image;
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
        # <https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/f4ca5fb76c589661efec611f92b8365925623985/device/community/device-oneplus-enchilada/modules-initfs>
        kernelModules = [
          "i2c_qcom_geni"
          "rmi_core"
          "rmi_i2c"
          "qcom_spmi_haptics"
        ];

        systemd.enable = true;
        systemd.storePaths =
          map
            (fw: {
              source = "${config.hardware.firmware}/lib/firmware/${fw}.zst";
              target = "/extra-firmware/${fw}.zst";
            })
            [
              "qcom/sdm845/OnePlus/enchilada/adsp.mbn"
              "qcom/sdm845/OnePlus/enchilada/cdsp.mbn"
              "qcom/sdm845/OnePlus/enchilada/ipa_fws.mbn"

              "qcom/sdm845/OnePlus/enchilada/a630_zap.mbn"
              "qcom/sdm845/OnePlus/enchilada/slpi.mbn"
              "ath10k/WCN3990/hw1.0/board-2.bin"
              "qca/crbtfw21.tlv"
              "qca/crnv21.bin"
              "qca/OnePlus/enchilada/crnv21.bin"

              "qcom/a630_sqe.fw"
              "qcom/a630_gmu.bin"
            ];
      };
    };

    services.q6voiced.settings = {
      q6voice_card = 0;
      q6voice_device = 6;
    };
  };

  meta.maintainers = [ lib.maintainers.kwaa ];
}
