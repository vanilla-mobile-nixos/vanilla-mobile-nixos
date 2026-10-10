{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "alsa-ucm-conf-sc7280";
  version = "0-unstable-2026-01-12";

  src = fetchFromGitHub {
    owner = "sc7280-mainline";
    repo = "alsa-ucm-conf";
    rev = "9d5563e6456e1a35e2d59c59130c50b2bbfe3c94";
    hash = "sha256-8OOOzG354x/qmLwQv91C/RrQdZ2L1OyI3Q27/bgmoi0=";
  };

  # A DisplayPort routing left over from `ucm2-dp` otherwise breaks the speaker.
  patches = [ ./clear-dp-mixer.patch ];

  # `ucm2-dp` adds the Fairphone 5 DisplayPort output. It's a separate tree,
  # because opening the DP PCM while the link is down also breaks the speaker.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/alsa
    cp -r ucm2 $out/share/alsa

    # Booting through UEFI gives the kernel DMI tables, and ALSA then uses the
    # DMI vendor-product as the card longname.
    ln -s "Fairphone 5.conf" "$out/share/alsa/ucm2/conf.d/qcm6490/fairphone-Fairphone5.conf"

    cp -r $out/share/alsa/ucm2 $out/share/alsa/ucm2-dp
    install -m644 ${./HiFi-dp.conf} $out/share/alsa/ucm2-dp/Fairphone/fp5/HiFi.conf

    runHook postInstall
  '';

  meta = {
    description = "ALSA UCM configuration for Qualcomm SC7280 devices";
    homepage = "https://github.com/sc7280-mainline/alsa-ucm-conf";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ marcusramberg ];
    platforms = [ "aarch64-linux" ];
  };
}
