self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.mobile-config-firefox;

  firefoxOverride = (
    prev: {
      extraPoliciesFiles = (prev.extraPoliciesFiles or [ ]) ++ [
        "${cfg.package}/lib/firefox/distribution/policies.json"
      ];

      extraPrefs = (prev.autoConfig or "") + ''
        // Allow autoconfig to run regular JS code.
        pref('general.config.sandbox_enabled', false);

        // Enable touch density.
        pref('browser.uidensity', 2);
      '';
      extraPrefsFiles = (prev.autoConfigFiles or [ ]) ++ [
        "${cfg.package}/lib/firefox/mobile-config-autoconfig.js"
      ];
    }
  );
in
{
  options.vanilla-mobile.mobile-config-firefox = {
    enable = lib.mkEnableOption "mobile-config-firefox";
    package = lib.mkPackageOption self.packages "mobile-config-firefox" { };

    firefoxPackage = lib.mkPackageOption pkgs "firefox" { };
    librewolfPackage = lib.mkPackageOption pkgs "librewolf" { };
  };

  config = lib.mkIf cfg.enable {
    programs.firefox.package = cfg.firefoxPackage.override firefoxOverride;
    programs.librewolf.package = cfg.librewolfPackage.override firefoxOverride;
  };

  meta.maintainers = [ lib.maintainers.junestepp ];
}
