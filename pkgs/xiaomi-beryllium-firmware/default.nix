{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
  fetchpatch,
}:

stdenvNoCC.mkDerivation {
  pname = "xiaomi-beryllium-firmware";
  version = "0-unstable-2025-12-22";

  src = fetchFromGitLab {
    owner = "sdm845-mainline";
    repo = "firmware-xiaomi-beryllium";
    rev = "d396d32118803235a58aab0d0bc3643256634a05";
    sha256 = "sha256-KKV6/2DJrz+keUVxKR3M6CQcCYQ518xMyxUqgIyAu/s=";
  };

  patches = [
    # Used by `iio-sensor-proxy`.
    (fetchpatch {
      name = "set-mount-matrix.patch";
      url = "https://gitlab.postmarketos.org/postmarketOS/pmaports/-/raw/f6f36733515651179905cd94b903ff0f19b41291/device/community/firmware-xiaomi-beryllium/mount-matrix.patch?inline=false";
      hash = "sha256-Yf9dETw8geWjwyuyM0Y7c8A+YDAsNGNtcA8kruh9BDw=";
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

    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "Firmware for Xiaomi Poco F1";
    homepage = "https://gitlab.com/sdm845-mainline/firmware-xiaomi-beryllium";
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
