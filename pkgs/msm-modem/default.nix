{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  makeWrapper,
  libqmi,
  gawk,
  gnugrep,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "msm-modem";
  version = "13";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "msm-modem";
    rev = finalAttrs.version;
    hash = "sha256-kKDqYrd7yI3beS7kMVN+xqTBfNC4NTUgch2t/rDM9LE=";
  };

  nativeBuildInputs = [
    meson
    ninja
    makeWrapper
  ];

  mesonFlags = [
    "-Ddownstream=false"
    "-Dopenrc=false"
  ];

  postInstall = ''
    wrapProgram $out/libexec/msm-modem-uim-selection \
        --prefix PATH : ${
          lib.makeBinPath [
            libqmi
            gawk
            gnugrep
          ]
        }
  '';

  meta = {
    description = "Common support for Qualcomm MSM modems";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/msm-modem";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ junestepp ];
    platforms = lib.platforms.linux;
  };
})
