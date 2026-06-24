{
  lib,
  stdenv,
  fetchFromGitHub,
  unstableGitUpdater,
  meson,
  cmake,
  pkg-config,
  dbus,
  ninja,
  makeBinaryWrapper,
  jq,
}:

stdenv.mkDerivation {
  pname = "iio-hyprland";
  version = "0-unstable-2026-02-26";

  src = fetchFromGitHub {
    owner = "JeanSchoeller";
    repo = "iio-hyprland";
    rev = "1dec30019fbe8cd375b6050eb597a01328435d79";
    hash = "sha256-YTbCWQVmpshvtY//e6kPQtbn/Msbjx9NN0j0LQFzfNE=";
  };

  patches = [
    # Switch to Hyprland Lua syntax.
    # See <https://github.com/JeanSchoeller/iio-hyprland/pull/42>.
    ./lua-support.patch
  ];

  buildInputs = [ dbus ];
  nativeBuildInputs = [
    meson
    cmake
    pkg-config
    ninja
    makeBinaryWrapper
  ];

  postInstall = ''
    wrapProgram $out/bin/iio-hyprland --prefix PATH : "${jq}/bin"
  '';

  passthru.updateScript = unstableGitUpdater { };

  meta = {
    description = "Listens to iio-sensor-proxy and automatically changes Hyprland output orientation";
    homepage = "https://github.com/JeanSchoeller/iio-hyprland";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ yusuf-duran ];
    platforms = lib.platforms.linux;
    mainProgram = "iio-hyprland";
  };
}
