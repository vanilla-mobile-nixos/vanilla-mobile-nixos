# This config is NOT meant to be used with the Disko CLI. It should only be used with
# the Disko image builder.
#
# The Fairphone 5 has no spare partition for the boot partition, so this builds a
# single GPT disk image (boot + root) that is flashed to the `userdata` partition.
# U-Boot and the initrd both map `userdata` as a disk to find the partitions inside it.
{ config, ... }:
let
  # Set to false for an unencrypted root filesystem.
  encrypt = true;

  sectorSize = toString config.vanilla-mobile.deviceInfo.imageSectorSize;

  rootFilesystem = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
  };
in
{
  disko.devices.disk.userdata = {
    type = "disk";
    device = "/dev/disk/by-loop-ref/userdata";
    imageName = "nixos-fairphone5";
    # The size of the image that will be flashed. The root partition is expanded
    # to the full size of `userdata` once booted into.
    imageSize = "6G";
    content = {
      type = "gpt";
      partitions = {
        # Keeps the boot partition off the very start of `userdata`.
        padding = {
          priority = 1;
          size = "15M";
        };
        boot = {
          priority = 2;
          type = "EF00";
          # vfat can't be auto-expanded by NixOS, so this must be the final desired size.
          size = "1G";
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
              "-S"
              sectorSize
            ];
          };
        };
        root = {
          # "Linux ARM64 root", so systemd-repart below can find it.
          type = "8305";
          size = "100%";
          content =
            if encrypt then
              {
                type = "luks";
                name = "crypt";
                settings = {
                  # Enable discard/TRIM support.
                  # There is some security tradeoff. See <https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)>.
                  allowDiscards = true;
                  # Improve SSD performance.
                  # See <https://wiki.archlinux.org/title/Dm-crypt/Specialties#Disable_workqueue_for_increased_solid_state_drive_(SSD)_performance>.
                  bypassWorkqueues = true;
                };
                extraFormatArgs = [
                  "--sector-size"
                  sectorSize
                ];
                # Just for initial encryption in the VM.
                passwordFile = "/tmp/nixos-root.key";
                content = rootFilesystem;
              }
            else
              rootFilesystem;
        };
      };
    };
  };

  vanilla-mobile.disko.enable = true;
  # To type the decryption password.
  boot.initrd.unl0kr.enable = encrypt;

  # Grow the root partition to fill `userdata`. The filesystem (and LUKS
  # container) is then grown by `fileSystems."/".autoResize`.
  boot.initrd.systemd.repart = {
    enable = true;
    device = "/dev/disk/by-loop-ref/userdata";
  };
  # The filesystem is grown after it's mounted, which must see the grown partition.
  boot.initrd.systemd.services.systemd-repart.before = [ "sysroot.mount" ];
  systemd.repart.partitions."20-root".Type = "root";
}
