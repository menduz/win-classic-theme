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
# PATH. `dev/screenshots.nix` gives them.
#
# It writes five files in the output directory:
#
#     <name>.png               a desktop with two windows and an open menu
#     <name>-widgets.png       the window of gtk3-widget-factory
#     <name>-widgets-gtk4.png  the window of gtk4-widget-factory
#     <name>-widgets-qt5.png   the Qt5 widget showcase
#     <name>-widgets-qt6.png   the Qt6 widget showcase
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

work=$(mktemp -d)
xvfb_pid=""
wm_pid=""
app_pid=""
bus_pid=""

kill_all() {
  local pid
  for pid in "$app_pid" "$wm_pid" "$xvfb_pid"; do
    if [ -n "$pid" ]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  app_pid=""
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
gtk-icon-theme-name=Adwaita
gtk-font-name=Liberation Sans 9
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
gtk-icon-theme-name=Adwaita
gtk-font-name=Liberation Sans 9
gtk-enable-animations=false
gtk-cursor-blink=false
gtk-hint-font-metrics=1
INI

cat >"$XDG_CONFIG_HOME/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="$name"/>
    <property name="title_font" type="string" value="Liberation Sans Bold 9"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="1"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
  </property>
</channel>
XML

export GTK_THEME=$name
export GTK2_RC_FILES=$theme_dir/gtk-2.0/gtkrc
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
  Xvfb -displayfd 7 -screen 0 "${size}x24" -nolisten tcp 7>"$work/display" \
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

# A window that holds common widgets. The window draws its own frame, so the
# picture holds the window alone. Each window has the same size for comparison.
#
#     shot_factory <program> <output file>
shot_factory() {
  local program=$1 file=$2 id

  start_x 1400x820
  start_wm

  "$program" >"$work/$program.log" 2>&1 &
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
  "$out_dir/$name-widgets.png"
  "$out_dir/$name-widgets-gtk4.png"
  "$out_dir/$name-widgets-qt5.png"
  "$out_dir/$name-widgets-qt6.png"
)

shot_showcase
shot_factory gtk3-widget-factory "$out_dir/$name-widgets.png"
shot_factory gtk4-widget-factory "$out_dir/$name-widgets-gtk4.png"
QT_QPA_PLATFORMTHEME=gtk2 QT_STYLE_OVERRIDE=gtk2 \
  shot_factory qt5-showcase "$out_dir/$name-widgets-qt5.png"
QT_QPA_PLATFORMTHEME=qt6gtk2 QT_STYLE_OVERRIDE=qt6gtk2 \
  shot_factory qt6-showcase "$out_dir/$name-widgets-qt6.png"

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
