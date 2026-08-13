# Fairphone 5 firmware blobs, extracted from a stock factory image.
# Source repo: <https://github.com/gitman-101111/FP5-firmware>
#
# Most of the work here is renaming: the blobs come out of the factory image
# under vendor names, but each driver looks for its own path and filename.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  pil-squasher,
  findutils,
}:
stdenvNoCC.mkDerivation {
  pname = "fairphone-fp5-firmware";
  version = "0-unstable-2026-08-07";

  src = fetchFromGitHub {
    owner = "gitman-101111";
    repo = "FP5-firmware";
    rev = "f23ab8555712c64f9e4d857acf743282df29296e"; # FP5-VT2Y.C.108.20260622
    hash = "sha256-5GGj7XEBws4ZWfy4zpBbLC9V7mWK21mKGwqKchlQbH8=";
  };

  nativeBuildInputs = [
    pil-squasher
    findutils
  ];

  buildPhase = ''
    runHook preBuild

    # Reassemble the split .mdt/.bNN blobs into single .mbn files.
    find . -name "*.mdt" -type f | while read -r mdt; do
      pil-squasher "''${mdt%.mdt}.mbn" "$mdt"
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dest="$out/lib/firmware/qcom/qcm6490/fairphone5"
    mkdir -p "$dest" "$out/lib/firmware/qca" "$out/lib/firmware/ath11k/WCN6750/hw1.0"

    cp -r ./* "$dest/"
    # hexagonfs contents are looked up relative to the firmware root.
    if [ -d ./hexagonfs ]; then
      cp -r ./hexagonfs/* "$dest/"
    fi

    # pd-mapper searches the firmware root rather than the device directory.
    find . -name "*.jsn" -exec cp -f {} "$out/lib/firmware/" \;
    find . -name "*.json" -exec cp -f {} "$out/lib/firmware/" \;

    # Names each driver actually asks for.
    find . -name "yupik_ipa_fws.mbn" -exec cp -f {} "$dest/ipa_fws.mbn" \;
    find . -name "vpu20_1v.mbn"      -exec cp -f {} "$dest/venus.mbn" \;
    find . -name "aw882xx_acf.bin"   -exec cp -f {} "$dest/aw88261_acf.bin" \;
    find . -name "msbtfw11.mbn"      -exec cp -f {} "$out/lib/firmware/qca/msbtfw11.mbn" \;
    find . -name "msnv11.bin"        -exec cp -f {} "$out/lib/firmware/qca/msnv11.bin" \;
    find . -name "bdwlan.bin"        -exec cp -f {} "$out/lib/firmware/ath11k/WCN6750/hw1.0/board.bin" \;
    find . -name "amss20.bin"        -exec cp -f {} "$out/lib/firmware/ath11k/WCN6750/hw1.0/amss.bin" \;
    find . -name "m3.bin"            -exec cp -f {} "$out/lib/firmware/ath11k/WCN6750/hw1.0/m3.bin" \;

    # The DTS names aw88261_acf.bin explicitly; if the source blob is ever
    # renamed this would otherwise leave the speakers with no firmware and no
    # error until they are silent on the device.
    if [ ! -f "$dest/aw88261_acf.bin" ]; then
      echo "ERROR: aw88261_acf.bin was not produced; is aw882xx_acf.bin still in the firmware repo?" >&2
      exit 1
    fi

    find "$out/lib/firmware" -type d -exec chmod 0755 {} \;
    find "$out/lib/firmware" -type f -exec chmod 0644 {} \;

    runHook postInstall
  '';

  meta = {
    description = "Firmware for the Fairphone 5";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
