# libcamera soft ISP tuning for the FP5 sensors, from pmaports. Laid out for
# `LIBCAMERA_IPA_CONFIG_PATH`.
{
  lib,
  runCommand,
}:
runCommand "fairphone5-libcamera-tuning"
  {
    meta = {
      maintainers = with lib.maintainers; [ marcusramberg ];
      platforms = lib.platforms.all;
    };
  }
  ''
    mkdir -p $out/simple
    cp ${./imx800.yaml} $out/simple/imx800.yaml
    cp ${./imx858.yaml} $out/simple/imx858.yaml
    cp ${./s5kjn1.yaml} $out/simple/s5kjn1.yaml
  ''
