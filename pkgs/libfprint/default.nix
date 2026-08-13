# libfprint with the FocalTech QSEE driver, which is what lets fprintd see the
# FP5's fingerprint sensor.
#
# The driver is not upstream and cannot be: it needs `core: discover
# firmware-described misc devices`, a change to libfprint's device discovery
# that is itself still out of tree. Devices on SPI or I2C described only by the
# device tree have no udev id to match on, so libfprint could not find them at
# all; that change lets a driver match a misc device by name and compatible.
# It comes from Dawid Wróbel's work on the Goodix QSEE sensor in other Qualcomm
# phones, which has the same shape as ours -- a sensor whose bus belongs to the
# secure world -- and this fork carries our driver on top of that branch.
#
# So this is nixpkgs' libfprint with the source swapped, not a separate
# package: everything that consumes libfprint (fprintd, GNOME) picks it up
# through the overlay.
{
  fetchFromGitHub,
  libfprint,
}:
libfprint.overrideAttrs (old: {
  version = "1.94.100-focaltech";

  src = fetchFromGitHub {
    owner = "marcusramberg";
    repo = "libfprint";
    rev = "a0439a5c2c15aa63c2dcf5bd9009a07e51333db5";
    hash = "sha256-NkS9WphywVYrn1Kmjc3nQrE6z+gJ/y/M0lYYRvI/f6w=";
  };

  # nixpkgs carries a backport for the Realtek driver that this source is
  # already newer than, and it does not apply.
  patches = [ ];

  # Built with `-Ddrivers=all` from nixpkgs, and the driver is not marked
  # optional, so it is included without any flag of its own.
})
