# This config is NOT meant to be used with the Disko CLI. It should only be used with
# the Disko image builder. It represents the boot and root images that will be
# created with Disko image builder and flashed to the phone. NixOS is then able to find
# the partitions using /dev/disk/by-label based on this config.
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
            # Continuous Discard/trim For SSDs. This partition is small and not written
            # to a ton, so I doubt performance will be an issue.
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
        imageSize = "5G";
        content = {
          type = "luks";
          name = "crypt";
          settings = {
            # Enable discard/TRIM support. fstrim shouldn't be needed, b/c BTRFS
            # discard=async is default.
            # See https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
            allowDiscards = true;
            # Improve SSD performance.
            # See https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance
            bypassWorkqueues = true;
          };
          extraFormatArgs = [
            "--label"
            label
            "--sector-size"
            (toString config.vanilla-mobile.deviceInfo.imageSectorSize)
          ];
          # Just for initial encryption in the VM.
          passwordFile = "/tmp/nixos-root.key";
          content = {
            type = "btrfs";
            extraArgs = [
              "--sectorsize"
              (toString config.vanilla-mobile.deviceInfo.imageSectorSize)
              "--force" # Force overwrite existing partition
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
  };
}
