#!/usr/bin/env bash
#
# Take the screenshots of one built theme.
#
#     screenshot.sh <theme directory> <theme name> <output directory> [demos]
#
# The theme directory is the one that holds `gtk-3.0/` and `xfwm4/`, that is
# `<store path>/share/themes/<name>`.
#
# The script needs Xvfb, Xfwm4, dbus, ImageMagick and the showcase programs in
# PATH. For the Plasma screenshot it needs PLASMA_ENV, a directory that holds
# KWin, plasmashell and their plugins, and FAKETIME_LIB, the library of
# libfaketime. `dev/screenshots.nix` gives them.
#
# It writes eight files in the output directory:
#
#     <name>.png                  a desktop with two windows and an open menu
#     <name>-plasma.png           the same windows on a Plasma desktop, with
#                                 the menu of the application launcher open
#     <name>-widgets.png          the window of gtk3-widget-factory
#     <name>-widgets-gtk4.png     the window of gtk4-widget-factory
#     <name>-widgets-qt5.png      the Qt5 widget showcase
#     <name>-widgets-qt6.png      the Qt6 widget showcase
#     <name>-opensnitch.png       the window of opensnitch-ui
#     <name>-opensnitch-prefs.png the Preferences dialog of opensnitch-ui
#
# With a fourth argument it writes the window of one demo of each toolkit in
# that directory:
#
#     <demo>-gtk3.png          the window of gtk3-demo --run=<demo>
#     <demo>-gtk4.png          the window of gtk4-demo --run=<demo>

set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "usage: screenshot.sh <theme directory> <theme name> <output directory> [demos]" >&2
  exit 2
fi

theme_dir=$(cd "$1" && pwd)
name=$2
out_dir=$3
demo_dir=${4:-}

# The demo of each toolkit that shows the widgets of a window.
demo=builder

# The size of the window of a widget factory. The two windows take the same
# size, thus the two pictures compare.
factory_width=1280
factory_height=720

# The middle of the Preferences button of opensnitch-ui, from the corner of the
# window below the title bar.
prefs_button_x=91
prefs_button_y=20

# The application launcher on the Plasma panel, and the first category of its
# menu. The Plasma screenshot opens that category.
launcher_x=12
launcher_y=716
category_x=150
category_y=537

work=$(mktemp -d)
xvfb_pid=""
wm_pid=""
app_pid=""
plasma_pid=""
bus_pid=""

kill_all() {
  local pid
  for pid in "$app_pid" "$plasma_pid" "$wm_pid" "$xvfb_pid"; do
    if [ -n "$pid" ]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  app_pid=""
  plasma_pid=""
  wm_pid=""
  xvfb_pid=""
  wait 2>/dev/null || true
}

cleanup() {
  local status=$?
  kill_all
  if [ -n "$bus_pid" ]; then
    kill "$bus_pid" 2>/dev/null || true
  fi
  if [ "$status" -ne 0 ]; then
    for log in "$work"/*.log; do
      if [ -s "$log" ]; then
        echo "--- $(basename "$log")" >&2
        cat "$log" >&2
      fi
    done
  fi
  rm -rf "$work"
  return "$status"
}
trap cleanup EXIT

mkdir -p "$out_dir"

# A home directory that holds nothing but this theme.
export HOME=$work/home
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
mkdir -p "$HOME/.themes" "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/gtk-4.0" \
  "$XDG_CONFIG_HOME/xfce4/xfconf/xfce-perchannel-xml" "$XDG_CACHE_HOME"
ln -sfn "$theme_dir" "$HOME/.themes/$name"

cat >"$XDG_CONFIG_HOME/gtk-3.0/settings.ini" <<INI
[Settings]
gtk-theme-name=$name
gtk-icon-theme-name=Chicago95
gtk-font-name=MS Sans Serif 8
gtk-enable-animations=false
gtk-cursor-blink=false
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=none
INI

# GTK4 does not read a theme by name. It reads this one file.
cat >"$XDG_CONFIG_HOME/gtk-4.0/gtk.css" <<CSS
@import url("file://$theme_dir/gtk-4.0/gtk.css");
CSS

cat >"$XDG_CONFIG_HOME/gtk-4.0/settings.ini" <<INI
[Settings]
gtk-icon-theme-name=Chicago95
gtk-font-name=MS Sans Serif 8
gtk-enable-animations=false
gtk-cursor-blink=false
gtk-font-rendering=manual
gtk-hint-font-metrics=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=none
gtk-xft-dpi=98304
INI

cat >"$XDG_CONFIG_HOME/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="$name"/>
    <property name="title_font" type="string" value="MS Sans Serif Bold 8"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="1"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
  </property>
</channel>
XML

# The same keys that Home Manager writes for a user, in the same order: the
# theme, then the settings. A style for `widget_class "*"` here would hide a
# font that the theme sets, and then no screenshot would show that fault.
cat >"$work/gtkrc-2.0" <<RC
include "$theme_dir/gtk-2.0/gtkrc"
gtk-font-name = "MS Sans Serif 8"
# The Qt style of GTK2 takes the icons of the program from this key. Without
# it a Qt window shows an empty button in place of each icon.
gtk-icon-theme-name = "Chicago95"
RC

export GTK_THEME=$name
export GTK2_RC_FILES=$work/gtkrc-2.0
# The theme has no icon of its own, and no application here needs a11y or a
# portal. Turn both off to keep the log clean and the start fast.
export GTK_A11Y=none
export GTK_USE_PORTAL=0
export NO_AT_BRIDGE=1

# GTK4 looks for a Vulkan or an OpenGL device. The X server of this script has
# none, and the driver stops the application in the Nix sandbox. The cairo
# renderer draws with the processor and needs no device. GTK3 reads neither
# name.
export GSK_RENDERER=cairo
export GDK_DISABLE=gl,vulkan
# gtk4-widget-factory has a video widget, and GTK4 stops when it does not find
# the GStreamer elements. No screenshot here shows a film.
export GTK_MEDIA=none

# Xfwm4 keeps its settings in Xfconf, and Xfconf needs a session bus. The bus
# starts here, after the home directory above, because the bus gives its own
# environment to Xfconfd. The bus of the user, if there is one, holds the
# settings of the user, so this script always makes its own.
#
# The bus reads /etc/dbus-1/session.conf. The Nix sandbox does not have that
# file, so DBUS_SESSION_CONF gives the one of the dbus package.
start_bus() {
  local args=(--sh-syntax)
  if [ -n "${DBUS_SESSION_CONF:-}" ]; then
    args+=(--config-file="$DBUS_SESSION_CONF")
  fi
  # The sandbox has no machine ID and no dbus-daemon at the usual place. The
  # bus says so on the error output and then starts, so keep the words in a
  # log instead of in the build.
  eval "$(dbus-launch "${args[@]}" 2>"$work/dbus.log")"
  export DBUS_SESSION_BUS_ADDRESS
  bus_pid=$DBUS_SESSION_BUS_PID
}
start_bus

# Start an X server on a free display and export DISPLAY.
start_x() {
  local size=$1
  # The sandbox has an empty /tmp, and the X server does not make this one.
  mkdir -p /tmp/.X11-unix 2>/dev/null || true
  rm -f "$work/display"
  Xvfb -displayfd 7 -screen 0 "${size}x24" -dpi 96 -nolisten tcp 7>"$work/display" \
    2>"$work/xvfb.log" &
  xvfb_pid=$!
  for _ in $(seq 1 100); do
    if [ -s "$work/display" ]; then
      DISPLAY=":$(tr -d '[:space:]' <"$work/display")"
      export DISPLAY
      return 0
    fi
    sleep 0.2
  done
  echo "screenshot.sh: Xvfb did not start" >&2
  cat "$work/xvfb.log" >&2
  return 1
}

stop_x() {
  kill_all
}

# Wait until a command is true, for at most 30 seconds.
wait_for() {
  for _ in $(seq 1 150); do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  echo "screenshot.sh: gave up waiting for: $*" >&2
  return 1
}

# Xprop says "no such atom" and still leaves the status at zero, so look at
# the answer itself.
wm_is_up() {
  xprop -root -notype _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q '0x'
}

start_wm() {
  xfwm4 --compositor=off --sm-client-disable >"$work/xfwm4.log" 2>&1 &
  wm_pid=$!
  wait_for wm_is_up
  # After the window manager, which paints the root window itself.
  xsetroot -solid '#3a6ea5' # the desktop color of Windows 98
}

# The desktop: the showcase window with an open menu, and a second window that
# shows the inactive title bar.
shot_showcase() {
  start_x 920x700
  start_wm

  rm -f "$work/ready"
  READY_FILE=$work/ready SHOWCASE_TITLE=$name showcase >"$work/showcase.log" 2>&1 &
  app_pid=$!
  wait_for test -s "$work/ready"
  sleep 1 # let the menu finish opening

  magick import -window root -screen "$out_dir/$name.png"
  stop_x
}

# The windows of shot_showcase on a Plasma desktop. KWin draws the title bars
# with the Aurorae decoration of the theme, and plasmashell draws the panel with
# the Plasma style of the theme. The panel at the bottom holds the application
# launcher, the task manager and the clock. The menu of the launcher is open,
# with the submenu of its first category.
shot_plasma() {
  local plasma_home=$work/plasma
  local layout=$plasma_home/share/plasma/look-and-feel/win-classic
  # KWin, plasmashell and their helpers run with the Plasma environment. The
  # showcase keeps the environment of the other screenshots.
  local plasma_vars=(
    PATH="$PLASMA_ENV/bin:$PATH"
    # The package of the theme holds the KWin decoration and the Plasma style.
    # The icon theme comes after the Plasma packages.
    XDG_DATA_DIRS="$plasma_home/share:$(dirname "$(dirname "$theme_dir")"):$PLASMA_ENV/share:$XDG_DATA_DIRS"
    XDG_CONFIG_DIRS="$plasma_home/xdg:$PLASMA_ENV/etc/xdg"
    XDG_MENU_PREFIX=plasma-
    XDG_RUNTIME_DIR="$work/plasma-run"
    QT_PLUGIN_PATH="$PLASMA_ENV/lib/qt-6/plugins"
    QML_IMPORT_PATH="$PLASMA_ENV/lib/qt-6/qml"
    QT_QPA_PLATFORMTHEME=kde
    QT_FORCE_STDERR_LOGGING=1
    XDG_CURRENT_DESKTOP=KDE
    KDE_FULL_SESSION=true
    KDE_SESSION_VERSION=6
    # The X server has no OpenGL. KWin then draws no effect and plasmashell
    # draws with the processor.
    KWIN_COMPOSE=N
    QT_XCB_GL_INTEGRATION=none
    QT_QUICK_BACKEND=software
  )

  # plasmashell takes the first layout from the look and feel package in
  # kdeglobals. This package holds the layout alone.
  rm -rf "$plasma_home" "$work/plasma-run"
  mkdir -p "$layout/contents/layouts" "$plasma_home/xdg" "$work/plasma-run"
  chmod 700 "$work/plasma-run"
  cat >"$layout/metadata.json" <<JSON
{ "KPackageStructure": "Plasma/LookAndFeel",
  "KPlugin": { "Id": "win-classic", "Name": "win-classic" } }
JSON
  cat >"$layout/contents/layouts/org.kde.plasma.desktop-layout.js" <<'JS'
var panel = new Panel;
panel.location = "bottom";
panel.height = 28;
panel.floating = false;
var launcher = panel.addWidget("org.kde.plasma.kicker");
launcher.currentConfigGroup = ["General"];
launcher.writeConfig("showRecentApps", false);
launcher.writeConfig("showRecentDocs", false);
launcher.writeConfig("showIconsRootLevel", true);
var tasks = panel.addWidget("org.kde.plasma.taskmanager");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", "");
panel.addWidget("org.kde.plasma.digitalclock");
var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; i++) {
  desktops[i].wallpaperPlugin = "org.kde.color";
  desktops[i].currentConfigGroup = ["Wallpaper", "org.kde.color", "General"];
  desktops[i].writeConfig("Color", "58,110,165");
}
JS
  cat >"$plasma_home/xdg/kdeglobals" <<INI
[KDE]
LookAndFeelPackage=win-classic

[General]
font=MS Sans Serif,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Icons]
Theme=Chicago95

[WM]
activeFont=MS Sans Serif,8,-1,5,700,0,0,0,0,0,0,0,0,0,0,1
INI
  # The decoration of the theme, with the buttons of decorationLayout.
  cat >"$plasma_home/xdg/kwinrc" <<INI
[org.kde.kdecoration2]
library=org.kde.kwin.aurorae.v2
theme=__aurorae__svg__$name
ButtonsOnLeft=M
ButtonsOnRight=IAX
BorderSize=Normal
BorderSizeAuto=false
INI
  printf '[Theme]\nname=%s\n' "$name" >"$plasma_home/xdg/plasmarc"

  # The programs of the screenshots, in the menu of the application launcher.
  mkdir -p "$plasma_home/share/applications"
  local entry
  for entry in \
    "showcase|Win Classic Showcase|preferences-desktop-theme|Settings;" \
    "gtk3-widget-factory|GTK3 Widget Factory|applications-development|Development;" \
    "gtk4-widget-factory|GTK4 Widget Factory|applications-development|Development;" \
    "qt5-showcase|Qt5 Showcase|applications-development|Development;" \
    "qt6-showcase|Qt6 Showcase|applications-development|Development;" \
    "opensnitch-ui|OpenSnitch|security-high|Network;"; do
    IFS='|' read -r exec entry_name icon categories <<<"$entry"
    cat >"$plasma_home/share/applications/$exec.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$entry_name
Exec=$exec
Icon=$icon
Categories=$categories
DESKTOP
  done

  start_x 920x730
  # Plasma starts services on the session bus, and the next screenshots must
  # not find them. Thus this shot has a bus of its own. The bus starts the
  # services with its environment, thus it starts after the X server.
  local main_bus=$DBUS_SESSION_BUS_ADDRESS main_bus_pid=$bus_pid
  # shellcheck disable=SC2016
  env "${plasma_vars[@]}" bash -c 'eval "$(dbus-launch --sh-syntax \
    ${DBUS_SESSION_CONF:+--config-file="$DBUS_SESSION_CONF"})" &&
    echo "$DBUS_SESSION_BUS_ADDRESS $DBUS_SESSION_BUS_PID"' \
    >"$work/plasma-bus" 2>>"$work/dbus.log"
  read -r DBUS_SESSION_BUS_ADDRESS bus_pid <"$work/plasma-bus"

  env "${plasma_vars[@]}" kwin_x11 --replace >"$work/kwin.log" 2>&1 &
  wm_pid=$!
  wait_for wm_is_up
  # The clock stops at this time. Qt counts its timers with the monotonic
  # clock, and libfaketime does not change that one.
  env "${plasma_vars[@]}" LD_PRELOAD="$FAKETIME_LIB" \
    FAKETIME="2026-01-01 12:00:00" FAKETIME_DONT_FAKE_MONOTONIC=1 \
    plasmashell --no-respawn >"$work/plasmashell.log" 2>&1 &
  plasma_pid=$!
  wait_for xdotool search --class plasmashell
  sleep 5 # the panel and the wallpaper draw

  # The menu of the launcher is open in place of the menu of the showcase.
  rm -f "$work/ready"
  SHOWCASE_NO_MENU=1 READY_FILE=$work/ready SHOWCASE_TITLE=$name showcase \
    >"$work/showcase-plasma.log" 2>&1 &
  app_pid=$!
  wait_for test -s "$work/ready"
  sleep 2 # the task manager shows the windows

  xdotool mousemove "$launcher_x" "$launcher_y" click 1
  sleep 4 # the menu opens
  # Qt Quick takes a click on an item after the pointer moves over it.
  xdotool mousemove $((category_x - 10)) $((category_y - 7))
  sleep 0.5
  xdotool mousemove "$category_x" "$category_y"
  sleep 0.5
  xdotool click 1
  sleep 4 # the submenu opens

  magick import -window root -screen "$out_dir/$name-plasma.png"
  stop_x
  kill "$bus_pid" 2>/dev/null || true
  DBUS_SESSION_BUS_ADDRESS=$main_bus
  bus_pid=$main_bus_pid
}

# A window that holds common widgets. The window draws its own frame, so the
# picture holds the window alone. Each window has the same size for comparison.
#
#     shot_factory <program> <output file> [preload library]
shot_factory() {
  local program=$1 file=$2 preload=${3:-} id

  start_x 1400x820
  start_wm

  if [ -n "$preload" ]; then
    LD_PRELOAD="$preload" "$program" >"$work/$program.log" 2>&1 &
  else
    "$program" >"$work/$program.log" 2>&1 &
  fi
  app_pid=$!
  # The window manager gives the focus to the window it maps, and the window
  # of the application is the only one here.
  wait_for xdotool getactivewindow
  sleep 3 # the window draws its pages

  id=$(xdotool getactivewindow)
  xdotool windowmove "$id" 0 0
  xdotool windowsize "$id" "$factory_width" "$factory_height"
  sleep 2 # the widgets take the new size
  magick import -window "$id" -screen "$file"
  stop_x
}

# The window of opensnitch-ui and its Preferences dialog. The program uses Qt6
# and PyQt, thus it shows the GTK2 style of the theme through qt6gtk2. It holds
# widgets that no showcase here holds: a tool box, a tab bar with icons and a
# table of events.
#
#     shot_opensnitch <output file> <preferences output file>
shot_opensnitch() {
  local file=$1 prefs_file=$2 id prefs_id
  # The program puts its local socket below the runtime directory of the
  # session. This script has no session, so it gives it one directory of its
  # own. The settings go below XDG_CONFIG_HOME.
  local run_dir=$work/run

  start_x 1400x820
  start_wm

  # The run of an earlier scheme leaves the settings and the socket, and a
  # picture must not depend on the run before it.
  rm -rf "$XDG_CONFIG_HOME/opensnitch" "$run_dir"
  mkdir -p "$run_dir"
  chmod 700 "$run_dir"

  # The daemon connects to this socket. No daemon runs here, so the program
  # shows the window of a user who has nothing connected.
  XDG_RUNTIME_DIR=$run_dir opensnitch-ui --socket "unix://$work/osui.sock" \
    >"$work/opensnitch.log" 2>&1 &
  app_pid=$!
  wait_for test -S "$run_dir/opensnitch/io.github.evilsocket.opensnitch"

  # The window stays hidden while there is a system tray, and Qt finds one on
  # this X server. A second program connects to the local socket of the first
  # one, which then shows its window and stays.
  XDG_RUNTIME_DIR=$run_dir opensnitch-ui --socket "unix://$work/osui-second.sock" \
    >"$work/opensnitch-second.log" 2>&1 || true
  wait_for xdotool search --onlyvisible --name "OpenSnitch Network Statistics"
  sleep 3 # the tabs and the table take their size

  id=$(xdotool search --onlyvisible --name "OpenSnitch Network Statistics" | head -1)
  xdotool windowmove "$id" 0 0
  xdotool windowsize "$id" "$factory_width" "$factory_height"
  sleep 2
  magick import -window "$id" -screen "$file"

  # The Preferences dialog opens from the second button of the tool bar. The
  # font and the style are the same on each run, thus the button is at the same
  # place. The wait below stops the build if it moves.
  eval "$(xdotool getwindowgeometry --shell "$id")"
  xdotool mousemove $((X + prefs_button_x)) $((Y + prefs_button_y)) click 1
  wait_for xdotool search --onlyvisible --name '^Preferences$'
  sleep 2

  prefs_id=$(xdotool search --onlyvisible --name '^Preferences$' | head -1)
  magick import -window "$prefs_id" -screen "$prefs_file"
  stop_x
}

# The window of one demo. Both programs take `--run`.
#
#     shot_demo <program> <output file>
shot_demo() {
  local program=$1 file=$2 id

  start_x 1000x760
  start_wm

  "$program" --run="$demo" >"$work/$program-$demo.log" 2>&1 &
  app_pid=$!
  wait_for xdotool getactivewindow
  sleep 3

  id=$(xdotool getactivewindow)
  xdotool windowmove "$id" 0 0
  sleep 1
  magick import -window "$id" -screen "$file"
  stop_x
}

files=(
  "$out_dir/$name.png"
  "$out_dir/$name-plasma.png"
  "$out_dir/$name-widgets.png"
  "$out_dir/$name-widgets-gtk4.png"
  "$out_dir/$name-widgets-qt5.png"
  "$out_dir/$name-widgets-qt6.png"
  "$out_dir/$name-opensnitch.png"
  "$out_dir/$name-opensnitch-prefs.png"
)

shot_showcase
shot_plasma
shot_factory gtk3-widget-factory "$out_dir/$name-widgets.png" \
  "${GTK_FACTORY_PULSE_BLOCKER:-}"
shot_factory gtk4-widget-factory "$out_dir/$name-widgets-gtk4.png" \
  "${GTK_FACTORY_PULSE_BLOCKER:-}"
QT_QPA_PLATFORMTHEME=gtk2 QT_STYLE_OVERRIDE=gtk2 \
  shot_factory qt5-showcase "$out_dir/$name-widgets-qt5.png"
QT_QPA_PLATFORMTHEME=qt6gtk2 QT_STYLE_OVERRIDE=qt6gtk2 \
  shot_factory qt6-showcase "$out_dir/$name-widgets-qt6.png"
# The plugin of Qt6 answers to `gtk2` as well as to `qt6gtk2`. The name here is
# the one that the modules put in the session of the user.
QT_QPA_PLATFORMTHEME=gtk2 QT_STYLE_OVERRIDE=gtk2 \
  shot_opensnitch "$out_dir/$name-opensnitch.png" \
  "$out_dir/$name-opensnitch-prefs.png"

if [ -n "$demo_dir" ]; then
  mkdir -p "$demo_dir"
  shot_demo gtk3-demo "$demo_dir/$demo-gtk3.png"
  shot_demo gtk4-demo "$demo_dir/$demo-gtk4.png"
  files+=("$demo_dir/$demo-gtk3.png" "$demo_dir/$demo-gtk4.png")
fi

# The screenshots come from a screen with an alpha channel and an offset that
# no one needs. The date chunk goes out too: without it, the same screen gives
# the same file on each build.
magick mogrify -alpha off -colorspace sRGB +repage -strip \
  -define png:exclude-chunks=date "${files[@]}"

echo "screenshot.sh: wrote the screenshots of $name in $out_dir"
