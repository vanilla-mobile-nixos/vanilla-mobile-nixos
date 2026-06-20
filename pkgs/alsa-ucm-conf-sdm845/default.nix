{
  lib,
  stdenvNoCC,
  fetchFromGitLab,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "alsa-ucm-conf-sdm845";
  version = "0-unstable-2026-05-07";

  src = fetchFromGitLab {
    owner = "sdm845-mainline";
    repo = "alsa-ucm-conf";
    rev = "628b9900cdd2b9b8356201293f1da5396cf0ca27";
    hash = "sha256-8RvxmqD7zU/kZO7AYU/XOf9nXKewM8vAHordJfSvwS4=";
  };

  patches = [
    # See <https://gitlab.com/sdm845-mainline/alsa-ucm-conf/-/merge_requests/32>.
    ./uboot-beryllium.patch
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/alsa
    cp -r ucm2 $out/share/alsa

    runHook postInstall
  '';

  meta = {
    description = "ALSA UCM configuration for Qualcomm SDM845 devices";
    homepage = "https://github.com/AsahiLinux/alsa-ucm-conf-asahi";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = [ "aarch64-linux" ];
  };
})
