self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.installer;

  crossPkgs =
    if cfg.enableCrossPkgs && cfg.buildSystem != pkgs.stdenv.buildPlatform.system then
      import pkgs.path {
        localSystem = cfg.buildSystem;
        crossSystem = pkgs.stdenv.hostPlatform.system;
      }
    else
      pkgs;
in
{
  options.vanilla-mobile.installer = {
    enable = lib.mkEnableOption "installer mode";

    buildSystem = lib.mkOption {
      type = lib.types.str;
      default = pkgs.stdenv.buildPlatform.system;
      example = "x86_64-linux";
      description = "Set to the real build system when using binfmt.";
    };
    crossPkgs = lib.mkOption {
      type = lib.types.pkgs;
      readOnly = true;
      description = ''
        nixppkgs instance for packages that should be cross compiled when
        using binfmt.
      '';
    };
    vanillaMobileCrossPkgs = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        `self.packages` for packages that should be cross compiled when
        using binfmt.
      '';
    };
    enableCrossPkgs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        This speeds up builds during development. Don't use when you just
        want the cached packages.
      '';
    };

    ssh.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Whether to enable SSH over USB.";
    };
  };

  config = (
    lib.mkMerge [
      {
        vanilla-mobile.installer = {
          crossPkgs = crossPkgs;
          vanillaMobileCrossPkgs = (self.getPackages crossPkgs);
        };
        vanilla-mobile.disko.imageBuildSystem = cfg.buildSystem;
      }
      (lib.mkIf cfg.enable {
        services.getty.helpLine = ''
          The "nixos" and "root" accounts have empty passwords.

          To set up a wireless connection, run `nmtui`.
        '';

        # -- User --

        users.users.nixos = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
          ];
          # Allow the graphical user to login without password
          initialHashedPassword = "";
        };
        # Allow the user to log in as root without a password.
        users.users.root.initialHashedPassword = "";
        # Allow passwordless sudo.
        security.sudo.wheelNeedsPassword = false;

        # Automatically log in at the virtual consoles.
        services.getty.autologinUser = "nixos";

        # -- Other --

        # Provide networkmanager for easy network configuration.
        networking.networkmanager.enable = true;

        # Allow touch typing in the TTY.
        services.buffyboard = {
          enable = true;
          settings.input.touchscreen = true;
        };
      })
      (lib.mkIf (cfg.enable && cfg.ssh.enable) {
        services.getty.helpLine = ''
          You can log in with SSH over USB with:
            `ssh nixos@${config.vanilla-mobile.usb-gadget.network.serverAddress}`
        '';

        # Allow SSH over USB.
        systemd.services.usb-moded-turn-off-rescue-mode.enable = false;

        services.openssh = {
          enable = true;
          # We're making it easy to SSH in, but only over USB.
          openFirewall = false;
          listenAddresses = [
            {
              addr = config.vanilla-mobile.usb-gadget.network.serverAddress;
            }
          ];
          settings = {
            # Root login makes installation simpler.
            PermitRootLogin = "yes";
            PermitEmptyPasswords = "yes";
          };
        };
        security.pam.services.sshd.allowNullPassword = true;

        # Support connections from many terminals.
        environment.enableAllTerminfo = true;
      })

    ]
  );
}
