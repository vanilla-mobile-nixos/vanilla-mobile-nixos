{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "fp5-fingerprint-tools";
  version = "0-unstable-2026-09-02";

  src = fetchFromGitHub {
    owner = "marcusramberg";
    repo = "fp5-fingerprint-tools";
    rev = "d9320448e575c2e219b1100655d0465b09f58d92";
    hash = "sha256-JWwvcnRp+bX3d6qdvM82p4E3O9UNTfZ89xUk89Qu/Yg=";
  };

  makeFlags = [ "PREFIX=$(out)" ];

  meta = {
    description = "Tools for the Fairphone 5 fingerprint trusted application (ftharness, ffsupplicant)";
    homepage = "https://github.com/marcusramberg/fp5-fingerprint-tools";
    license = lib.licenses.gpl2Only;
    maintainers = with lib.maintainers; [ marcusramberg ];
    platforms = lib.platforms.linux;
  };
}
