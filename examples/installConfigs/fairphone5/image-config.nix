# The Fairphone 5 has no spare partition for the ESP, so this builds a GPT disk
# image (ESP + root) that is flashed to the `userdata` partition. U-Boot and
# the initrd both map `userdata` as a disk to find the partitions inside it.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
  closureInfo = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel ]; };
  sectorSize = config.vanilla-mobile.deviceInfo.imageSectorSize;
in
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  image.repart = {
    name = "nixos-fairphone5";
    inherit sectorSize;

    partitions = {
      # Keeps the ESP off the very start of `userdata`.
      "00-padding".repartConfig = {
        Type = "linux-generic";
        SizeMinBytes = "15M";
        SizeMaxBytes = "15M";
      };
      "10-esp" = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          # systemd-boot boots this until the first `nixos-rebuild`.
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "ESP";
          FileSystemSectorSize = sectorSize;
          SizeMinBytes = "1G";
        };
      };
      "20-root" = {
        storePaths = [ config.system.build.toplevel ];
        contents."/nix-path-registration".source = "${closureInfo}/registration";
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          FileSystemSectorSize = sectorSize;
          Minimize = "guess";
          GrowFileSystem = true;
        };
      };
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
      options = [ "umask=0077" ];
    };
  };

  # Grow the root partition to fill `userdata` on first boot.
  systemd.repart.enable = true;
  systemd.repart.partitions."20-root".Type = "root";

  # Register the store paths that were baked into the image.
  boot.postBootCommands = ''
    if [ -f /nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration
      touch /etc/NIXOS
      ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
      rm -f /nix-path-registration
    fi
  '';
}
