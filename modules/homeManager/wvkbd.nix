self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.wvkbd;

  getConfigValue =
    value:
    if lib.isList value then
      lib.concatMapStringsSep "," getConfigValue value
    else if value == "" then
      ""
    else
      lib.escapeShellArg (toString value);

  wrapper = pkgs.symlinkJoin {
    inherit (cfg.package)
      version
      meta
      ;
    pname = "${cfg.package.pname}-wrapper";

    paths = [ cfg.package ];

    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

    postBuild = ''
      wrapProgram $out/bin/wvkbd-mobintl --add-flags "${
        lib.concatMapAttrsStringSep " " (name: value: "-${lib.escapeShellArg name} ${getConfigValue value}")
          (
            (lib.removeAttrs cfg.settings [ "exclusive" ])
            // lib.optionalAttrs (!cfg.settings.exclusive) { non-exclusive = ""; }
          )
      }"
    '';
  };
in
{
  options.programs.wvkbd = {
    enable = lib.mkEnableOption "wvkbd";

    package = lib.mkPackageOption pkgs "wvkbd" { };
    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Configured wvkbd wrapper.";
    };

    service.enable = lib.mkEnableOption "wvkbd Systemd service";

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType =
          with lib.types;
          attrsOf (oneOf [
            str
            int
            (listOf str)
          ]);

        options = {
          exclusive = lib.mkOption {
            type = lib.types.bool;
            default = true;
            example = false;
            description = ''
              Whether to request an exclusive zone from the comnpositor.
              When disabled, the keyboard can overlap windows.
            '';
          };
        };
      };

      example = {
        H = 350;
        L = 200;
        R = 5;
        alpha = 240;
        bg = "1e1e2e";
        fg = "1e1e2e";
        fg-sp = "1e1e2e";
        press = "cba6f7";
        press-sp = "cba6f7";
        text = "cdd6f4";
        text-sp = "cdd6f4";
        fn = "monospace";
      };

      description = ''
        See the <https://git.sr.ht/~proycon/wvkbd/tree/master/item/wvkbd.1.scd> for
        available options. Don't include the `--` or `-` prefixes.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.wvkbd.finalPackage = wrapper;

    home.packages = [ cfg.finalPackage ];

    systemd.user.services.wvkbd = lib.mkIf cfg.service.enable {
      Unit = {
        Description = "On Screen Keyboard";
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];

      Service = {
        ExecStart = "${lib.getExe cfg.finalPackage} --hidden";
        Restart = "always";
      };
    };
  };

  meta.maintainers = [ lib.maintainers.junestepp ];
}
