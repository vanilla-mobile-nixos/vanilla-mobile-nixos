# This config is NOT meant to be used with the Disko CLI. It should only be used with
# the Disko image builder. It represents the boot and root images that will be
# created with Disko image builder and flashed to the mobile device. NixOS is then able
# to find the partitions using /dev/disk/by-label based on this config.
#
# You should understand BTRFS before using it. Further configuration such as scrubbing or
# disabling copy-on-write in specific directories may be warranted.
{ config, ... }:
{
  disko.devices.disk = {
    boot =
      let
        label = "nixos-boot";
      in
      {
        type = "disk";
        device = "/dev/disk/by-label/${label}";
        imageName = label;
        # vfat can't be auto-expanded by NixOS, so the initial image size must be
        # the final desired size.
        imageSize = "2G";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [
            # `/boot/loader/random-seed` shouldn't be world accessible.
            "umask=0077"
            # Continuous Discard/trim For SSDs.
            "discard"
          ];
          extraArgs = [
            "-n"
            label
            "-S"
            (toString config.vanilla-mobile.deviceInfo.imageSectorSize)
          ];
        };
      };
    root =
      let
        label = "nixos-root";
      in
      {
        type = "disk";
        device = "/dev/disk/by-label/${label}";
        imageName = label;
        # The size of the image that will be flashed. It will expanded to the full
        # available space once booted into.
        imageSize = "4G";
        content = {
          type = "btrfs";
          extraArgs = [
            "--label"
            label
            "--sectorsize"
            (toString config.vanilla-mobile.deviceInfo.imageSectorSize)
          ];

          subvolumes = {
            "@root" = {
              mountpoint = "/";
              mountOptions = [
                "compress=zstd"
                "noatime"
              ];
            };
            "@home" = {
              mountpoint = "/home";
              mountOptions = [
                "compress=zstd"
                "noatime"
              ];
            };
            "@nix" = {
              mountpoint = "/nix";
              mountOptions = [
                "compress=zstd"
                "noatime"
              ];
            };
          };
        };
      };
  };

  vanilla-mobile.disko.enable = true;
}
