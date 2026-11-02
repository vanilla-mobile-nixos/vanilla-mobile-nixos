{
  hyprgrass,
  wf-touch,
  fetchFromGitHub,
}:
(hyprgrass.override {
  wf-touch = wf-touch.overrideAttrs {
    version = "0-unstable-2021-03-19";
    src = fetchFromGitHub {
      owner = "WayfireWM";
      repo = "wf-touch";
      rev = "8974eb0f6a65464b63dd03b842795cb441fb6403";
      hash = "sha256-MjsYeKWL16vMKETtKM5xWXszlYUOEk3ghwYI85Lv4SE=";
    };
  };
}).overrideAttrs
  (
    finalAttrs: prevAttrs: rec {
      version = "0.57.0";

      src = fetchFromGitHub {
        owner = "horriblename";
        repo = "hyprgrass";
        tag = "hl-${version}";
        hash = "sha256-Z4la09NwLkQD9tui840xTOPVoF1UnOUWkvLHcfxGxvY=";
      };
    }
  )
