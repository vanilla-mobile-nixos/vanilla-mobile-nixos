{
  lib,
  stdenvNoCC,
  fetchgit,
}:

stdenvNoCC.mkDerivation {
  pname = "focal32-firmware";
  version = "2.5.3.0-cdf0f80-230614";

  # Extracted from the stock firmware. It isn't in FairBlobs/FP5-firmware.
  src = fetchgit {
    url = "https://code.bas.es/marcus/fp5-fingerprint-firmware";
    rev = "6eecceae7b314d15006d211713806de507368cab";
    hash = "sha256-zmQ7YCtTM/2L9DkyQqFlsB9Iqszuu7i92k3EZzDn8Jg=";
  };

  # Not squashed: the QSEECOM TEE driver loads the .mdt and .bNN segments itself.
  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/lib/firmware focal32.mdt focal32.b0[0-7]
    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "FocalTech fingerprint trusted application for the Fairphone 5";
    homepage = "https://code.bas.es/marcus/fp5-fingerprint-firmware";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ marcusramberg ];
    platforms = lib.platforms.all;
  };
}
