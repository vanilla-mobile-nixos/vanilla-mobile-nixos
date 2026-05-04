{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchFromGitLab,
  python3Packages,
  runCommand,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dtbtool-exynos";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "dsankouski";
    repo = "dtbtool-exynos";
    rev = finalAttrs.version;
    hash = "sha256-BI7jIpUo2dbmoQapgC0L/egBhlvYFn2TKcSF9lm86JY=";
  };

  strictDeps = true;

  buildInputs = [
    python3Packages.libfdt
  ];

  patches = map (patch: "${finalAttrs.passthru.patches}/${patch}") [
    "0001-Makefile-do-not-add-libfdt.so-to-OBJ_FILES.patch"
    "0002-Makefile-do-not-strip-the-produced-binary.patch"
    "0003-dtbtool-exynos-convert-all-space-indentation-to-tabs.patch"
    "0004-scan_dtb_path-be-less-verbose-when-scanning-director.patch"
    "0005-scan_dtb_path-free-struct-from-scandir.patch"
    "0006-dtbtool-exynos-zero-allocated-dtb_files-memory.patch"
    "0007-dtbtool-exynos-allocate-memory-for-dtbs-as-needed.patch"
    "0008-dtbtool-exynos-remove-fail-goto.patch"
    "0009-dtbtool-exynos-free-allocated-dtb_files-before-exit.patch"
    "0010-load_dtbh_block-free-allocated-memory.patch"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp dtbTool-exynos $out/bin

    runHook postInstall
  '';

  passthru.patches =
    runCommand "dtbtool-exynos-patches"
      {
        version = "0-unstable-2025-10-12";

        src = fetchFromGitLab {
          domain = "gitlab.postmarketos.org";
          owner = "postmarketOS";
          repo = "pmaports";
          rev = "0007041862d959b66578a44bfe179d3d8bc696b3";
          sparseCheckout = [ "main/dtbtool-exynos" ];
          hash = "sha256-JftvGwBAkxBBkECWqYI6b8/FReR4XKbhj0xUXTxSKF8=";
        };

        meta = {
          license = lib.licenses.gpl3Only;
          platforms = lib.platforms.all;
        };
      }
      ''
        mkdir -p $out
        cp -R $src/main/dtbtool-exynos/*.patch $out
      '';

  meta = {
    description = "Tool for compiling a dtb.img for Exynos SOC";
    homepage = "https://github.com/dsankouski/dtbtool-exynos";
    license = lib.licenses.bsd3;
    mainProgram = "dtbTool-exynos";
    platforms = lib.platforms.all;
  };
})
