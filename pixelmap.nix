# SVG files from pixel maps. A pixel map is a list of rows, and one character
# of a row is one pixel. The palette gives the color of each character. A
# character that is not in the palette is no pixel.
{ lib }:
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

in
{
  inherit svgFile;
}
