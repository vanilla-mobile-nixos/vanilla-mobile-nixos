{
  hyprgrass,
  wf-touch,
  fetchFromGitHub,
}:
(hyprgrass.override {
  # See <https://github.com/NixOS/nixpkgs/pull/526498>.
  wf-touch = wf-touch.overrideAttrs {
    buildInputs = [ ];
    mesonFlags = [
      "-Dtests=disabled"
    ];
  };
}).overrideAttrs
  (
    finalAttrs: prevAttrs: rec {
      version = "0.55.4";

      src = fetchFromGitHub {
        owner = "horriblename";
        repo = "hyprgrass";
        tag = "hl-${version}";
        hash = "sha256-tCt7FNc1RBHou/ym7B0XzoOqqNq8Df+dizEDkAgJ4U0=";
      };

      patches = prevAttrs.patches or [ ] ++ [
        # See <https://github.com/horriblename/hyprgrass/issues/391>.
        ./workspace-swipe-edge.patch
      ];
    }
  )
