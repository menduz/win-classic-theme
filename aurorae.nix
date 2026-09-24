# The KWin decoration, an Aurorae theme. It has the pixels of xfwm4/.
#
# The result is a set of file names and file contents. Each SVG element is a
# pixel map: one character is one pixel, and the palette gives its color.
#
#     " " no pixel      b  window color     h  highlight     s  shadow
#     k   border        t  title bar        g  button glyph
{
  lib,
  name,
  colors,
}:
let
  # One rectangle for each run of one character in a row.
  rowRects =
    palette: x: y: row:
    let
      step =
        runs: char:
        let
          last = lib.last runs;
        in
        if runs != [ ] && last.char == char then
          lib.init runs ++ [ (last // { width = last.width + 1; }) ]
        else
          runs
          ++ [
            {
              inherit char;
              start = if runs == [ ] then 0 else last.start + last.width;
              width = 1;
            }
          ];
      runs = lib.foldl' step [ ] (lib.stringToCharacters row);
    in
    lib.concatMapStrings (
      run:
      lib.optionalString (palette ? ${run.char})
        ''<rect x="${toString (x + run.start)}" y="${toString y}" width="${toString run.width}" height="1" fill="${palette.${run.char}}"/>''
    ) runs;

  # An element of the SVG file at a place of its own. The first rectangle has
  # no color. It gives the element its full size when a row starts or ends
  # with no pixel.
  element =
    palette: id: x: rows:
    let
      width = lib.stringLength (lib.head rows);
    in
    {
      inherit width;
      height = lib.length rows;
      svg = ''
        <g id="${id}"><rect x="${toString x}" y="0" width="${toString width}" height="${toString (lib.length rows)}" fill="#000000" fill-opacity="0"/>${
          lib.concatImapStrings (y: row: rowRects palette x (y - 1) row) rows
        }</g>
      '';
    };

  # The elements side by side, with a gap of one pixel.
  svgFile =
    elements:
    let
      placed =
        lib.foldl'
          (
            acc: e:
            let
              made = element e.palette e.id acc.x e.rows;
            in
            {
              x = acc.x + made.width + 1;
              height = lib.max acc.height made.height;
              svg = acc.svg + made.svg;
            }
          )
          {
            x = 0;
            height = 0;
            svg = "";
          }
          elements;
    in
    ''
      <svg xmlns="http://www.w3.org/2000/svg" width="${toString placed.x}" height="${toString placed.height}" viewBox="0 0 ${toString placed.x} ${toString placed.height}">
      ${placed.svg}</svg>
    '';

  palette = title: {
    b = colors.bgcolor;
    h = colors.highlight;
    s = colors.shadow;
    k = colors.border;
    t = title;
    g = colors.buttonscolor;
  };

  # The frame. The title bar is the top edge: 4 rows of frame, 18 rows of
  # title and 2 rows of window color.
  frame = [
    {
      part = "topleft";
      rows = [
        "bbbbb"
        "bhhhh"
      ]
      ++ lib.replicate 2 "bhbbb"
      ++ lib.replicate 18 "bhbbt"
      ++ lib.replicate 2 "bhbbb";
    }
    {
      part = "top";
      rows = [
        "b"
        "h"
      ]
      ++ lib.replicate 2 "b"
      ++ lib.replicate 18 "t"
      ++ lib.replicate 2 "b";
    }
    {
      part = "topright";
      rows = [
        "bbbbk"
        "hhhsk"
      ]
      ++ lib.replicate 2 "bbbsk"
      ++ lib.replicate 18 "tbbsk"
      ++ lib.replicate 2 "bbbsk";
    }
    {
      part = "left";
      rows = [ "bhbbb" ];
    }
    {
      part = "center";
      rows = [ "b" ];
    }
    {
      part = "right";
      rows = [ "bbbsk" ];
    }
    {
      part = "bottomleft";
      rows = lib.replicate 3 "bhbbb" ++ [
        "bssss"
        "kkkkk"
      ];
    }
    {
      part = "bottom";
      rows = [
        "b"
        "b"
        "b"
        "s"
        "k"
      ];
    }
    {
      part = "bottomright";
      rows = lib.replicate 3 "bbbsk" ++ [
        "ssssk"
        "kkkkk"
      ];
    }
  ];

  # A maximized window has no frame. The title bar is 18 rows of title and 2
  # rows of window color.
  maximized = lib.replicate 18 "t" ++ lib.replicate 2 "b";

  decoration = svgFile (
    map (f: {
      palette = palette colors.activetitle;
      id = "decoration-${f.part}";
      inherit (f) rows;
    }) frame
    ++ map (f: {
      palette = palette colors.inactivetitle;
      id = "decoration-inactive-${f.part}";
      inherit (f) rows;
    }) frame
    ++ [
      {
        palette = palette colors.activetitle;
        id = "decoration-maximized-center";
        rows = maximized;
      }
      {
        palette = palette colors.inactivetitle;
        id = "decoration-maximized-inactive-center";
        rows = maximized;
      }
    ]
  );

  # A disabled glyph is a shadow with a highlight one pixel below and to the
  # right.
  disable =
    rows:
    let
      at =
        x: y:
        if y < 0 || x < 0 || y >= lib.length rows then
          " "
        else
          let
            row = lib.elemAt rows y;
          in
          if x >= lib.stringLength row then " " else builtins.substring x 1 row;
    in
    lib.imap0 (
      y: row:
      lib.concatImapStrings (
        x1: char:
        let
          x = x1 - 1;
        in
        if char == "g" then
          "s"
        else if at (x - 1) (y - 1) == "g" then
          "h"
        else
          char
      ) (lib.stringToCharacters row)
    ) rows;

  # A button is 14 rows high. The file adds one empty row above and below, so
  # that the icon of the window, which has the height of a button, is 16 rows.
  button =
    { normal, pressed }:
    let
      pad =
        rows:
        [ (lib.fixedWidthString (lib.stringLength (lib.head rows)) " " "") ]
        ++ rows
        ++ [
          (lib.fixedWidthString (lib.stringLength (lib.head rows)) " " "")
        ];
    in
    svgFile [
      {
        palette = palette colors.activetitle;
        id = "active-center";
        rows = pad normal;
      }
      {
        palette = palette colors.activetitle;
        id = "pressed-center";
        rows = pad pressed;
      }
      {
        palette = palette colors.activetitle;
        id = "deactivated-center";
        rows = pad (disable normal);
      }
    ];

  # A raised button. The face is 13 columns wide and 11 rows high, and the
  # glyph takes 11 of those columns.
  up =
    glyph:
    [ "hhhhhhhhhhhhhhhk" ]
    ++ map (row: "hbb${row}sk") glyph
    ++ [
      "hssssssssssssssk"
      "kkkkkkkkkkkkkkkk"
    ];

  # A pressed button. The face is one row higher, and the glyph moves one pixel
  # down and to the right.
  down =
    glyph:
    [ "kkkkkkkkkkkkkkkk" ]
    ++ map (row: "ksb${row}bh") (
      [ "bbbbbbbbbbb" ] ++ map (row: "b" + builtins.substring 0 10 row) glyph
    )
    ++ [ "khhhhhhhhhhhhhhh" ];

  minimizeGlyph = lib.replicate 8 "bbbbbbbbbbb" ++ [
    "gggggggbbbb"
    "gggggggbbbb"
    "bbbbbbbbbbb"
  ];

  maximizeGlyph = [
    "bbbbbbbbbbb"
    "gggggggggbb"
    "gggggggggbb"
  ]
  ++ lib.replicate 6 "gbbbbbbbgbb"
  ++ [
    "gggggggggbb"
    "bbbbbbbbbbb"
  ];

  restoreGlyph = [
    "bbbbbbbbbbb"
    "bbggggggbbb"
    "bbggggggbbb"
    "bbgbbbbgbbb"
    "ggggggbgbbb"
    "ggggggbgbbb"
    "gbbbbgggbbb"
    "gbbbbgbbbbb"
    "gbbbbgbbbbb"
    "ggggggbbbbb"
    "bbbbbbbbbbb"
  ];

  closeGlyph = [
    "bbbbbbbbbbb"
    "bbbbbbbbbbb"
    "bggbbbbggbb"
    "bbggbbggbbb"
    "bbbggggbbbb"
    "bbbbggbbbbb"
    "bbbggggbbbb"
    "bbggbbggbbb"
    "bggbbbbggbb"
    "bbbbbbbbbbb"
    "bbbbbbbbbbb"
  ];

  squareButton = glyph: {
    normal = up glyph;
    pressed = down glyph;
  };

  # The close button is two columns wider. The two columns on the left have no
  # pixel, and they keep the close button apart from the others.
  closeButton =
    let
      square = squareButton closeGlyph;
    in
    {
      normal = map (row: "  " + row) square.normal;
      pressed = map (row: "  " + row) square.pressed;
    };
in
{
  "metadata.desktop" = ''
    [Desktop Entry]
    Name=${name}
    X-KDE-PluginInfo-Name=${name}
    X-KDE-PluginInfo-Category=
    X-KDE-PluginInfo-License=GPL
  '';

  "${name}rc" = ''
    [General]
    ActiveTextColor=${colors.activetitletext}
    InactiveTextColor=${colors.inactivetitletext}
    TitleAlignment=Left
    TitleVerticalAlignment=Center
    Animation=0

    [Layout]
    BorderLeft=5
    BorderRight=5
    BorderBottom=5
    TitleEdgeTop=4
    TitleEdgeBottom=2
    TitleEdgeLeft=6
    TitleEdgeRight=6
    TitleEdgeTopMaximized=0
    TitleEdgeBottomMaximized=2
    TitleEdgeLeftMaximized=2
    TitleEdgeRightMaximized=2
    TitleBorderLeft=3
    TitleBorderRight=2
    TitleHeight=18
    ButtonWidth=16
    ButtonWidthClose=18
    ButtonHeight=16
    ButtonSpacing=0
    ButtonMarginTop=1
    ButtonMarginTopMaximized=1
    ExplicitButtonSpacer=2
    PaddingLeft=0
    PaddingRight=0
    PaddingTop=0
    PaddingBottom=0
  '';

  "decoration.svg" = decoration;
  "minimize.svg" = button (squareButton minimizeGlyph);
  "maximize.svg" = button (squareButton maximizeGlyph);
  "restore.svg" = button (squareButton restoreGlyph);
  "close.svg" = button closeButton;
}
