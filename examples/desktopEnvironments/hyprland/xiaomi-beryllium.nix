{
  wayland.windowManager.hyprland.settings = {
    config = {
      # Extra on bottom to to work around the curvature of the screen.
      general.gaps_out = {
        top = 10;
        left = 10;
        right = 10;
        bottom = 20;
      };
      # To look more natural with the heavily rounded screen.
      decoration.rounding = 15;
    };

    monitor = [
      # Important to define for iio-hyprland.
      {
        output = "DSI-1";
        mode = "preferred";
        position = "auto";
        scale = 2;
      }
    ];
  };
  services.iio-hyprland.output = "DSI-1";
}
