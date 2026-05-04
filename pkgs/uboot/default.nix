# See <https://gitlab.postmarketos.org/tauchgang/tauchgang-ci/-/blob/main/devices.toml>
# for the information needed to add most new devices.
# Reference <https://gitlab.postmarketos.org/tauchgang/tauchgang-ci/-/blob/main/common.sh>
# if a new image building utility needs to be made.
{
  lib,
  ubootUtils,
  runCommand,
  ubootPackages,
  dtbtool-exynos,
}:
let
  inherit (ubootUtils) buildTauchgangUBoot mkAndroidBootImage mkAndroidBootImageQCDT;
in
{
  xiaomi-beryllium-tianma = buildTauchgangUBoot {
    pname = "xiaomi-beryllium-tianma";
    dtb = "qcom/sdm845-xiaomi-beryllium-tianma";
    defconfig = "qcom_defconfig qcom-phone.config";
  };
  xiaomi-beryllium-tianma-boot-image = mkAndroidBootImage {
    uboot = ubootPackages.xiaomi-beryllium-tianma;
  };
  xiaomi-beryllium-ebbg = buildTauchgangUBoot {
    pname = "xiaomi-beryllium-ebbg";
    dtb = "qcom/sdm845-xiaomi-beryllium-ebbg";
    defconfig = "qcom_defconfig qcom-phone.config";
  };
  xiaomi-beryllium-ebbg-boot-image = mkAndroidBootImage {
    uboot = ubootPackages.xiaomi-beryllium-tianma;
  };

  samsung-a2corelte = buildTauchgangUBoot {
    pname = "samsung-a2corelte";
    dtb = "exynos/exynos7870-a2corelte";
    defconfig = "exynos-mobile_defconfig";
  };
  samsung-a2corelte-boot-image = mkAndroidBootImageQCDT {
    uboot = ubootPackages.samsung-a2corelte;
    page_size = 2048;
    device_tree_image = runCommand "exynos-dtb-img" { } ''
      ${lib.getExe dtbtool-exynos} --output $out \
        ${ubootPackages.samsung-a2corelte}/u-boot.dtb
    '';
  };
}
