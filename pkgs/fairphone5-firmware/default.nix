{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  pil-squasher,
}:

stdenvNoCC.mkDerivation {
  pname = "fairphone5-firmware";
  version = "0-unstable-2026-01-09";

  src = fetchFromGitHub {
    owner = "FairBlobs";
    repo = "FP5-firmware";
    rev = "a4908f548e6f88965e78b1478af1751b6a854fc9";
    hash = "sha256-XRklo4XfRrskmIxdyY9duU8nF0svoQV90KwaF15ISjk=";
  };

  nativeBuildInputs = [ pil-squasher ];

  # Mainline remoteproc wants monolithic .mbn files.
  buildPhase = ''
    runHook preBuild

    for mdt in *.mdt; do
      pil-squasher "''${mdt%.mdt}.mbn" "$mdt"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    fw=$out/lib/firmware/qcom/qcm6490/fairphone5
    install -Dm644 -t $fw \
      a660_zap.mbn adsp.mbn cdsp.mbn modem.mbn wpss.mbn \
      adspr.jsn adsps.jsn adspua.jsn battmgr.jsn cdspr.jsn modemr.jsn
    install -Dm644 yupik_ipa_fws.mbn $fw/ipa_fws.mbn
    install -Dm644 aw882xx_acf.bin $fw/aw88261_acf.bin
    install -Dm644 vpu20_1v.mbn $fw/venus.mbn
    cp -r --no-preserve=mode modem_pr $fw/

    install -Dm644 -t $out/lib/firmware/qca msbtfw11.mbn msnv11.bin

    # HexagonFS for hexagonrpcd.
    mkdir -p $out/share/qcom/qcm6490/Fairphone
    cp -r --no-preserve=mode hexagonfs $out/share/qcom/qcm6490/Fairphone/fp5

    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "Firmware for Fairphone 5";
    homepage = "https://github.com/FairBlobs/FP5-firmware";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ marcusramberg ];
    platforms = lib.platforms.all;
  };
}
