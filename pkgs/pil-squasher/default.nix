# Reassembles Qualcomm .mdt/.bNN firmware splits into single .mbn files.
# Not in nixpkgs.
{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "pil-squasher";
  version = "0-unstable-2020-11-12";

  src = fetchFromGitHub {
    owner = "linux-msm";
    repo = "pil-squasher";
    rev = "3c9f8b8756ba6e4dbf9958570fd4c9aea7a70cf4";
    hash = "sha256-MEW85w3RQhY3tPaWtH7OO22VKZrjwYUWBWnF3IF4YC0=";
  };

  makeFlags = [ "prefix=$(out)" ];

  meta = {
    description = "Squash Qualcomm PIL firmware splits into a single mbn";
    homepage = "https://github.com/linux-msm/pil-squasher";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    mainProgram = "pil-squasher";
  };
}
