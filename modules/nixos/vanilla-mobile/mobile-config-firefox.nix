self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vanilla-mobile.mobile-config-firefox;
in
{
  options.vanilla-mobile.mobile-config-firefox = {
    enable = lib.mkEnableOption "mobile-config-firefox";
    package = lib.mkPackageOption self.packages "mobile-config-firefox" { };

    firefoxPackage = lib.mkPackageOption pkgs "firefox" { };
  };

  config = lib.mkIf cfg.enable {
    # Don't let our policies get overwritten.
    environment.etc."firefox/policies/policies.json".enable = false;
    programs.firefox = {
      package = cfg.firefoxPackage.override (prev: {
        extraPolicies = (prev.extraPolicies or { }) // config.programs.firefox.policies;
        extraPoliciesFiles = (prev.extraPoliciesFiles or [ ]) ++ [
          "${cfg.package}/lib/firefox/distribution/policies.json"
        ];
      });

      autoConfig = ''
        // Allow autoconfig to run regular JS code.
        pref('general.config.sandbox_enabled', false);

        // Enable touch density.
        pref('browser.uidensity', 2);
      '';
      autoConfigFiles = [
        "${cfg.package}/lib/firefox/mobile-config-autoconfig.js"
      ];
    };
  };
}
