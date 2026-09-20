# The interface font of the theme. "lou" made these two fonts with FontStruct
# after the MS Sans Serif of Windows. The directories below hold the files of
# the author, with the license and the readme that the license asks for.
#
# The bold file gives itself the family "MS Sans Serif Bold" and the style
# "Regular". A toolkit that asks for bold text then gets a fake bold of the
# regular file. The build writes the name table of that file again, so the two
# files make one family with two styles.
{
  lib,
  runCommand,
  python3Packages,
}:
runCommand "ms-sans-serif-1.0"
  {
    nativeBuildInputs = [ python3Packages.fonttools ];

    meta = {
      description = "MS Sans Serif, the FontStruct font of \"lou\"";
      homepage = "https://fontstruct.com/fontstructions/show/1384746";
      license = lib.licenses.cc-by-sa-30;
      platforms = lib.platforms.all;
    };
  }
  ''
    fonts=$out/share/fonts/truetype
    doc=$out/share/doc/ms-sans-serif
    install -Dm644 ${./ms-sans-serif}/"MS Sans Serif.ttf" "$fonts/MS Sans Serif.ttf"
    python3 ${./name-bold.py} \
      ${./ms-sans-serif-bold}/"MS Sans Serif Bold.ttf" \
      "$fonts/MS Sans Serif Bold.ttf"

    # fontconfig reads this directory of each package in `fonts.packages`. The
    # rule keeps the text of a pixel font sharp, in a Qt program as in a GTK
    # program.
    install -Dm644 ${./60-ms-sans-serif.conf} \
      "$out/etc/fonts/conf.d/60-ms-sans-serif.conf"

    # The license asks for the other files of the archive beside the font.
    install -Dm644 ${./ms-sans-serif}/license.txt "$doc/ms-sans-serif/license.txt"
    install -Dm644 ${./ms-sans-serif}/readme.txt "$doc/ms-sans-serif/readme.txt"
    install -Dm644 ${./ms-sans-serif-bold}/license.txt "$doc/ms-sans-serif-bold/license.txt"
    install -Dm644 ${./ms-sans-serif-bold}/readme.txt "$doc/ms-sans-serif-bold/readme.txt"
  ''
