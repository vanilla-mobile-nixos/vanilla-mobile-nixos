self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.disko;

  realBuildPkgs = self.inputs.nixpkgs.legacyPackages.${cfg.imageBuildSystem};
in
{
  options.vanilla-mobile.disko = {
    enable = lib.mkEnableOption "disko";

    imageBuildSystem = lib.mkOption {
      type = lib.types.str;
      default = pkgs.stdenv.buildPlatform.system;
      example = "x86_64-linux";
      description = "Set to the real build system when using binfmt.";
    };
  };

  config = lib.mkIf (config.disko.devices != { }) {
    disko.imageBuilder = {
      imageFormat = "raw";
      # Our kernels don't have all the modules required for virtualization.
      kernelPackages = pkgs.linuxPackages;
      useVirtualDevices = false;
    }
    // lib.optionalAttrs (cfg.imageBuildSystem != pkgs.stdenv.buildPlatform.system) {
      enableBinfmt = true;
      pkgs = realBuildPkgs;
      kernelPackages = realBuildPkgs.linuxPackages;
    };

    # Grow the filesystem from the size of the image flashed to the full available
    # space on the partition it was flashed to.
    fileSystems."/".autoResize = true;

    # By default, bootctl gets mad that /boot isn't a partitioned device when building
    # the image. It also errors on the phone, b/c the boot partition isn't marked as
    # EFS in the GPT table. Setting `SYSTEMD_RELAX_ESP_CHECKS=1` fixes this.
    # UBoot doesn't care about the partition flag.
    systemd.package =
      let
        pkg = pkgs.systemd;
      in
      pkgs.symlinkJoin {
        inherit (pkg)
          name
          pname
          version
          meta
          passthru
          outputs
          ;
        paths = [ pkg ];
        nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
        postBuild = ''
          ln -s ${pkg.dev} $dev
          ln -s ${pkg.debug} $debug
          ln -s ${pkg.man} $man

          wrapProgram $out/bin/bootctl --set SYSTEMD_RELAX_ESP_CHECKS 1
        '';
      };
    # <https://github.com/NixOS/nixpkgs/blob/348370fcc9f71865fa1a6c090a8d588c7033fb4f/nixos/modules/system/boot/systemd/coredump.nix#L63>
    # doesn't work with the systemd wrapper above.
    systemd.coredump.enable = false;
    # Initrd has issues with the systemd wrapper above.
    boot.initrd.systemd.package = pkgs.systemd;
  };
}
