{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
  fetchpatch,
}:

stdenvNoCC.mkDerivation {
  pname = "oneplus-sdm845-firmware";
  version = "0-unstable-2026-04-28";

  src = fetchFromGitLab {
    owner = "sdm845-mainline";
    repo = "firmware-oneplus-sdm845";
    rev = "3e31a0c3e5a061645c09f805387b49fa9d35acbf";
    hash = "sha256-DeOlhchDGi0Pso3w8ZlM7q3Tdkmt3Ji+GyEmepkISTE=";
  };

  patches = [
    # See <https://gitlab.com/sdm845-mainline/firmware-oneplus-sdm845/-/merge_requests/3>.
    (fetchpatch {
      name = "0001-oneplus6-set-mount-matrix.patch";
      url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/1b853b79baecb837f53504a5bc947d3130bcaaa6/device/community/firmware-oneplus-sdm845/0001-oneplus6-set-mount-matrix.patch?inline=false";
      hash = "sha256-kuxEve7dTBH78ojp02P5RECSnitf8Ns6/DR1ikCLuJo=";
    })
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    while IFS="" read -r _i || [ -n "$_i" ]; do
      install -Dm644 "$_i" "$out/$_i"
    done < "${./firmware.files}"

    # Files to be included to add sensor support.
    while IFS="" read -r _i || [ -n "$_i" ]; do
      install -Dm644 "$_i" "$out/''${_i#"./usr"}"
    done < "${./sensor.files}"

    ln -s oneplus6 $out/share/qcom/sdm845/OnePlus/enchilada
    ln -s oneplus6 $out/share/qcom/sdm845/OnePlus/fajita

    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "Firmware for OnePlus 6 / 6T";
    homepage = "https://gitlab.com/sdm845-mainline/firmware-oneplus-sdm845";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ kwaa ];
    platforms = lib.platforms.all;
  };
}
