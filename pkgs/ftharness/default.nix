{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "ftharness";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -o ftharness ftharness.c
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ftharness $out/bin/ftharness
    runHook postInstall
  '';

  meta = {
    description = "Bring-up client for the Fairphone 5 focal32 fingerprint trusted application";
    longDescription = ''
      Loads the FocalTech FT9362 trusted application ("focal32") through the
      QSEECOM TEE driver and runs the init sequence the vendor HAL runs, so
      that the kernel side can be verified before any fingerprint stack
      exists. Needs root: the application is loaded through /dev/teepriv0,
      which requires CAP_SYS_ADMIN.
    '';
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "ftharness";
  };
}
