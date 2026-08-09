#!@bash@/bin/bash
if @procps@/bin/pgrep -x wl-screenrec >/dev/null 2>&1; then
  @procps@/bin/pkill wl-screenrec
  @libnotify@/bin/notify-send "Screen Recording" "Recording stopped"
else
  # Choose: area selection or full output
  MODE=$(printf "area\noutput" | @rofi@/bin/rofi -dmenu -p "Record" -theme-str 'listview {lines: 2;}')
  case "$MODE" in
    area)
      GEOMETRY=$(@slurp@/bin/slurp 2>/dev/null)
      [ -z "$GEOMETRY" ] && exit 0
      SELECTION="-g $GEOMETRY"
      ;;
    output)
      OUTPUT=$(niri msg outputs 2>/dev/null | @gnugrep@/bin/grep -oP '\(\K[^)]+' | @rofi@/bin/rofi -dmenu -p "Output" -theme-str 'listview {lines: 3;}')
      [ -z "$OUTPUT" ] && exit 0
      SELECTION="-o $OUTPUT"
      ;;
    *) exit 0 ;;
  esac
  @coreutils@/bin/mkdir -p "$HOME/Videos"
  FILENAME="$HOME/Videos/recording-$(@coreutils@/bin/date +%Y-%m-%d-%H-%M-%S).mp4"
  @wlScreenrec@/bin/wl-screenrec $SELECTION -f "$FILENAME" &
  disown
  @libnotify@/bin/notify-send "Screen Recording" "Recording started: $(@coreutils@/bin/basename "$FILENAME")"
fi
@procps@/bin/pkill -RTMIN+10 waybar 2>/dev/null || true
