self:
{
  config,
  lib,
  ...
}:
let
  cfg = config.vanilla-mobile.device.oneplus-fajita;
in
{
  options.vanilla-mobile.device.oneplus-fajita = {
    enable = lib.mkEnableOption "OnePlus 6T (oneplus-fajita)";
  };

  config = lib.mkIf cfg.enable {
    vanilla-mobile = {
      # The 6T shares everything with the 6 except the device tree; its
      # firmware paths point at the enchilada ones too.
      device.oneplus-enchilada.enable = true;
      deviceInfo = {
        name = "OnePlus 6T";
        codename = "oneplus-fajita";
        dtb = "qcom/sdm845-oneplus-fajita.dtb";
        uboot = self.packages.ubootPackages.oneplus-fajita-boot-image;
      };
    };
  };

  meta.maintainers = [ lib.maintainers.marcusramberg ];
}
