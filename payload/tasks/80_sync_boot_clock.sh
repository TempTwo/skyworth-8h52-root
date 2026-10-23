#!/system/bin/sh
# One-time /system patch: boot-time clock sync instead of the 2017 pin.
#
# This board has no RTC and /system/etc/init.bigfish.sh line 19 ran
# `busybox date -s 201701010000.00` on every boot, so every app saw 2017 until
# something else fixed the clock.  Installs /system/etc/timesync.sh (LAN router
# time poller, no DNS, no WAN) and rewires the vendor boot script to launch it.
# The vendor file is backed up in /data/local/tmp/ and on this USB stick.
#
# Run as init root (boot-shell payload), the same context the vendor's own
# `date -s` ran in, so the kernel clock set inside timesync.sh is allowed.

BB=/system/bin/busybox
UD="$1"
TG=/system/etc/timesync.sh
BF=/system/etc/init.bigfish.sh
SRC_T="$UD/payload/timesync.sh"
SRC_BF="$UD/payload/init.bigfish.sh.new"
SRC_ORI="$UD/payload/init.bigfish.sh.orig"

echo "--- clock task: start ---"
$BB md5sum "$SRC_T" "$SRC_BF"
[ -f "$SRC_T" ] && [ -f "$SRC_BF" ] || { echo "clock task: missing payload under $UD, abort"; exit 1; }

# syntax gate first: never install a script that sh rejects
$BB sh -n "$SRC_T" || { echo "clock task: timesync.sh syntax BAD, abort"; exit 1; }
$BB sh -n "$SRC_BF" || { echo "clock task: init.bigfish.sh.new syntax BAD, abort"; exit 1; }

# idempotent: already installed, jump straight to the live sync check
if [ -f "$TG" ] && $BB grep -q "timesync.sh" "$BF"; then
    echo "clock task: already installed, refresh only"
else
    $BB cp "$BF" /data/local/tmp/init.bigfish.sh.bak
    $BB cp "$BF" "$SRC_ORI" 2>/dev/null
    mount -o rw,remount /system || { echo "clock task: remount rw FAILED, abort"; exit 1; }
    $BB cp "$SRC_T" "$TG"
    $BB cp "$SRC_BF" "$BF"
    chown 0:0 "$TG" "$BF"
    chmod 755 "$TG" "$BF"
    $BB sh -n "$TG" && $BB sh -n "$BF"
    mount -o ro,remount /system
    echo "clock task: installed, md5 now:"
    $BB md5sum "$TG" "$BF"
fi

# live check right away: if this boot still has the 2017 clock, fix it now
echo "--- clock task: live sync ---"
DRY=1 $BB sh "$TG"
$BB sh "$TG"
echo "clock task: date now: $($BB date)"
echo "--- clock task: done ---"
