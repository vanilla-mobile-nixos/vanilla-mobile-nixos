{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ssu-sysinfo";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "sailfishos";
    repo = "ssu-sysinfo";
    tag = finalAttrs.version;
    hash = "sha256-CGlijeREonFactQlaQVfgL7f+UhtZtgOLfAM6RGLE6k=";
  };

  makeFlags = [
    "DESTDIR=$(out)"
    "_PREFIX="
  ];

  postInstall = ''
    # Fix library symlinks.
    ldconfig -C temp $out/lib
  '';

  meta = {
    description = "Get ssu info without IPC";
    homepag = "https://github.com/sailfishos/ssu-sysinfo";
    license = with lib.licenses; [
      lgpl21Plus
      bsd3
    ];
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = lib.platforms.linux;
  };
})
