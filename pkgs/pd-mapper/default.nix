# Qualcomm protection-domain mapper.
#
# The DSPs expose their services from separate protection domains, and a client
# can only reach one once the PD map for that subsystem has been published over
# QRTR. pd-mapper reads the JSON maps shipped with the device firmware and does
# exactly that. Without it a DSP still boots and its root PD answers -- so
# sensors can be discovered and their attributes read -- while anything living
# in a service PD stays silent, which looks like working hardware that never
# produces data rather than like a missing daemon.
#
# Not in nixpkgs, unlike its siblings qrtr, rmtfs and tqftpserv.
{
  stdenv,
  lib,
  fetchFromGitHub,
  qmic,
  qrtr,
  xz,
}:

stdenv.mkDerivation {
  pname = "pd-mapper";
  version = "0-unstable-2023-05-26";

  src = fetchFromGitHub {
    owner = "linux-msm";
    repo = "pd-mapper";
    rev = "5ecd2fe926aca7abfe40724177f63b942cff3947";
    sha256 = "1xvls2h3fdnvzvis8h5axlf0qsnll75d1x76998x6dlfhbdwv7r3";
  };

  # pd-mapper finds its maps by reading a base path out of
  # /sys/module/firmware_class/parameters/path and searching under it; only if
  # that directory cannot be opened does it fall back to a compile-time
  # /lib/firmware. Neither route works here. NixOS points firmware_class at the
  # activated firmware tree, whose maps are zstd compressed -- and pd-mapper
  # only recognises ".jsn.xz" and ".jsn", so it opens that directory
  # successfully, matches nothing, and reports "no pd maps available" without
  # ever reaching the fallback.
  #
  # Rather than repoint firmware_class globally, which every other firmware
  # load depends on, read the base path from a file the unit owns. The unit
  # writes /run/pd-mapper there and stages decompressed maps to match.
  postPatch = ''
    substituteInPlace pd-mapper.c \
      --replace-fail '"/sys/module/firmware_class/parameters/path"' \
                     '"/run/pd-mapper/.firmware-path"'
  '';

  nativeBuildInputs = [ qmic ];
  buildInputs = [
    qrtr
    xz
  ];

  makeFlags = [ "prefix=${placeholder "out"}" ];

  meta = {
    description = "Qualcomm protection domain mapper";
    homepage = "https://github.com/linux-msm/pd-mapper";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    mainProgram = "pd-mapper";
  };
}
