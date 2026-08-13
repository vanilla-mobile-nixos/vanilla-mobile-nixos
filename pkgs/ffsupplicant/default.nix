{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "ffsupplicant";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -o ffsupplicant ffsupplicant.c
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ffsupplicant $out/bin/ffsupplicant
    runHook postInstall
  '';

  meta = {
    description = "QSEECOM listener supplicant, so trusted applications can reach their secure storage";
    longDescription = ''
      A QSEE application that needs to read or write a secure object blocks
      until the normal world answers it. The focal32 fingerprint application
      does this for everything it persists -- templates, calibration, its
      serial id -- so with nothing serving those requests it cannot enroll a
      finger at all.

      This registers listener services on /dev/teepriv0 and answers their
      requests. It is not trusted with anything: objects are encrypted,
      integrity-protected and, for RPMB, authenticated by the secure world
      before they ever cross this boundary, which is why the I/O can be
      delegated to an ordinary process.

      Two services are served. RPMB (listener 8192) relays 512-byte frames --
      built and MACed by the secure world -- to the UFS RPMB well-known LUN at
      /dev/bsg/0:0:0:49476. The GlobalPlatform file service (listener 28672)
      carries the sealed objects the application persists: its templates, its
      chip calibration and its serial id, rooted under a directory given by
      --store. Both message layouts follow Qualcomm's own listener
      implementations in qualcomm/minkipc.

      This is what a fingerprint surviving a reboot depends on: with the file
      service unimplemented the application's saves fail with an I/O error, and
      with it, a template written before a power cycle is read back after
      one.

      Needs root, for /dev/teepriv0.
    '';
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "ffsupplicant";
  };
}
