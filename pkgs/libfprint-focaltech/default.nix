# Adds the FocalTech QSEE driver, plus the out-of-tree change that lets
# libfprint discover devices only described by the device tree.
{
  fetchFromGitHub,
  libfprint,
}:
libfprint.overrideAttrs {
  version = "1.94.100-focaltech";

  src = fetchFromGitHub {
    owner = "marcusramberg";
    repo = "libfprint";
    rev = "e5912e8fc5f741d787746efcc9a7a70db45808fb";
    hash = "sha256-It402YbvPTYfE53kmCwkWRQcJ4lk/EJNWsz/9cFX8Ic=";
  };

  # nixpkgs' backports are already in this source.
  patches = [ ];
}
