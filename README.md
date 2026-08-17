# win-classic-theme

A Windows 9x theme for GTK2, GTK3, GTK4 and Xfwm4. It is a Nix build of
[Redmond97 SE](https://codeberg.org/Sliver_X/Redmond97-SE) by Sliver X.

[DEVELOPMENT.md](DEVELOPMENT.md) tells how the build works.

## Screenshots

### `windows-standard`

![](screenshots/win-classic-standard.png)

![The GTK3 widgets of the windows-standard scheme](screenshots/win-classic-standard-widgets.png)

![The GTK4 widgets of the windows-standard scheme](screenshots/win-classic-standard-widgets-gtk4.png)

![The Qt5 widgets of the windows-standard scheme](screenshots/win-classic-standard-widgets-qt5.png)

![The Qt6 widgets of the windows-standard scheme](screenshots/win-classic-standard-widgets-qt6.png)

### `dark`

![](screenshots/win-classic-dark.png)

![The GTK3 widgets of the dark scheme](screenshots/win-classic-dark-widgets.png)

![The GTK4 widgets of the dark scheme](screenshots/win-classic-dark-widgets-gtk4.png)

![The Qt5 widgets of the dark scheme](screenshots/win-classic-dark-widgets-qt5.png)

![The Qt6 widgets of the dark scheme](screenshots/win-classic-dark-widgets-qt6.png)

## Presets

Build one preset with its name:

```bash
nix build .#luna
```

| Preset             | Windows scheme                              |
| ------------------ | ------------------------------------------- |
| `windows-classic`  | the gray scheme of Windows 95 and 98        |
| `windows-standard` | the scheme of Windows 2000 and XP           |
| `dark`             | "Dusk Red", the dark scheme of this theme   |
| `luna`             | Luna, the blue scheme of Windows XP         |
| `luna-silver`      | Luna (Silver)                               |
| `luna-olive`       | Luna (Olive Green)                          |
| `brick`            | classic scheme "Brick"                      |
| `desert`           | classic scheme "Desert"                     |
| `eggplant`         | classic scheme "Eggplant"                   |
| `lilac`            | classic scheme "Lilac"                      |
| `maple`            | classic scheme "Maple"                      |
| `marine`           | classic scheme "Marine"                     |
| `plum`             | classic scheme "Plum"                       |
| `pumpkin`          | classic scheme "Pumpkin"                    |
| `rainy-day`        | classic scheme "Rainy Day"                  |
| `red-white-blue`   | classic scheme "Red White Blue"             |
| `rose`             | classic scheme "Rose"                       |
| `slate`            | classic scheme "Slate"                      |
| `spruce`           | classic scheme "Spruce"                     |
| `storm`            | classic scheme "Storm"                      |
| `teal`             | classic scheme "Teal"                       |
| `wheat`            | classic scheme "Wheat"                      |

`nix build .#default` builds the "Dusk Red" scheme. The name of the theme below
`share/themes` is `win-classic-<preset>`, with `win-classic-98` for
`windows-classic` and `win-classic-standard` for `windows-standard`.

## Colors

`.override` changes the colors of a package. A value here has priority over the
value of the preset:

```nix
win-classic-theme.packages.${system}.luna.override {
  name = "win-luna-red";
  colors = {
    activetitle = "#6c2525";
    activetitle1 = "#6c2525";
  };
}
```

| Name                | Default     | Function                        |
| ------------------- | ----------- | ------------------------------- |
| `bgcolor`           | `#303131`   | 3D objects, window background   |
| `fgcolor`           | `#dddddd`   | text on 3D objects              |
| `border`            | `#060606`   | borders                         |
| `selectedbg`        | `#6c2525`   | selection background            |
| `selectedtext`      | `#dddddd`   | selection text                  |
| `activetitle`       | `#6c2525`   | active title bar                |
| `activetitle1`      | `#6c2525`   | second color of the title bar   |
| `activetitletext`   | `#dddddd`   | active title bar text           |
| `inactivetitle`     | `#434444`   | inactive title bar              |
| `inactivetitletext` | `#8d8d8d`   | inactive title bar text         |
| `basecolor`         | `#1e2426`   | text boxes and lists            |
| `basefg`            | `#dddddd`   | text in text boxes and lists    |
| `tooltipbg`         | `#ffe0a8`   | tool tip background             |
| `tooltipfg`         | `#000000`   | tool tip text                   |
| `buttonscolor`      | `#dddddd`   | window button glyphs            |

Give each color as a six digit hex value with a `#` in front. The build
calculates the two 3D edges and the disabled text from `bgcolor`. See
[DEVELOPMENT.md](DEVELOPMENT.md) for those three colors, for `name` and for
`titlebarButtons`.

## NixOS

The overlay puts `win-classic-theme` in `pkgs`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    win-classic-theme.url = "github:menduz/win-classic-theme";
  };

  outputs =
    { nixpkgs, win-classic-theme, ... }:
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          { nixpkgs.overlays = [ win-classic-theme.overlays.default ]; }
          (
            { pkgs, ... }:
            {
              environment.systemPackages = [ pkgs.win-classic-theme ];
            }
          )
        ];
      };
    };
}
```

## Home Manager

```nix
{ inputs, pkgs, ... }:
let
  name = "win-classic-dark";
  theme = inputs.win-classic-theme.packages.${pkgs.system}.dark;
in
{
  gtk = {
    enable = true;
    theme = { inherit name; package = theme; };
  };

  # GTK4 reads this one file.
  xdg.configFile."gtk-4.0/gtk.css".text = ''
    @import url("file://${theme}/share/themes/${name}/gtk-4.0/gtk.css");
  '';
}
```

Xfwm4 reads the theme by name. Set the same name in the property
`/general/theme` of the channel `xfwm4`.

## License

GPL 3. See `LICENSE`. The images and the style sheets come from Redmond97 SE by
Sliver X.
