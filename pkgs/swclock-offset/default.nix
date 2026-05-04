{
  lib,
  stdenv,
  fetchFromGitLab,
  makeWrapper,
  coreutils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "swclock-offset";
  version = "0.2.6";

  src = fetchFromGitLab {
    domain = "gitlab.postmarketos.org";
    owner = "postmarketOS";
    repo = "swclock-offset";
    rev = finalAttrs.version;
    hash = "sha256-yIzPQshz3S3qcrjIn5/dh7tbFRFkks5AwBAeSHZeUBE=";
  };

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail "/usr/" "/"
    substituteInPlace systemd/swclock-offset-{boot,shutdown}.service \
      --replace-fail /usr/bin/ "$out/bin/"
  '';

  nativeBuildInputs = [ makeWrapper ];

  makeFlags = [ "DESTDIR=$(out)" ];

  postInstall = ''
    wrapProgram $out/bin/swclock-offset-boot \
        --prefix PATH : ${lib.makeBinPath [ coreutils ]}
    wrapProgram $out/bin/swclock-offset-shutdown \
        --prefix PATH : ${lib.makeBinPath [ coreutils ]}
  '';

  meta = {
    description = "Save/load real-time clock (RTC) offset for devices with a non-writable RTC";
    homepage = "https://gitlab.postmarketos.org/postmarketOS/swclock-offset";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
