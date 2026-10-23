#!/system/bin/sh
# Boot-time clock sync for this RTC-less box.
#
# The vendor boot script used to pin the kernel clock at 2017-01-01; instead of
# that the kernel clock is now pulled from the home router after the LAN is up.
# Everything is deliberately LAN-only: the TV drops non-app raw WAN sockets and
# busybox DNS (plain UDP 53), but the gateway itself always answers.
#
# Time sources, in order:
#   1. clash HTTP API on the gateway (Date header of GET /version)
#   2. any other HTTP the gateway serves (Date header)
#   3. NTP over -u nc to the gateway (port 123)
#
# With DRY=1 nothing is set; each source just prints what it measured.
# Runs as root from /system/etc/init.bigfish.sh (init gives full capabilities,
# so busybox date -s is allowed here even though su without them gets EPERM).

BB=/system/bin/busybox
LOGF=/data/local/tmp/boot_clock.log
DRY="${DRY:-0}"

log() { $BB echo "[clock] $*" >> "$LOGF"; }

# epoch from an RFC1123 Date header ("Fri, 23 Oct 2026 05:56:52 GMT")
date_to_epoch() {
    $BB echo "$1" | $BB sed 's/^ *Date: *//; s/,//g; s/:/ /g; s/  */ /g' |
    $BB awk '
        BEGIN { m["Jan"]=1;m["Feb"]=2;m["Mar"]=3;m["Apr"]=4;m["May"]=5;m["Jun"]=6
                m["Jul"]=7;m["Aug"]=8;m["Sep"]=9;m["Oct"]=10;m["Nov"]=11;m["Dec"]=12 }
        { d=$2-0; mon=$3; y=$4-0; h=$5-0; mi=$6-0; s=$7-0
          mo = m[mon]
          if (mo == "") { exit 9 }
          # days from civil (Hinnant), proleptic Gregorian
          yy=y; if (mo<=2) yy-=1
          era = int(yy/400)
          yoe = yy - era*400
          mp  = mo + ((mo<=2) ? 9 : -3)
          doy = int((153*mp+2)/5) + d-1
          doe = yoe*365 + int(yoe/4) - int(yoe/100) + doy
          days = era*146097 + doe - 719468
          printf "%d\n", days*86400 + h*3600 + mi*60 + s
        }'
}

http_date() {  # $1 host, $2 port, $3 path -> "Date: ..." line or empty
    $BB printf "GET $3 HTTP/1.1\r\nHost: $1\r\nConnection: close\r\n\r\n" |
        $BB nc -w 4 "$1" "$2" |
        $BB grep -i "^[Dd]ate:" | $BB head -1
}

ntp_date() {  # $1 host, $2 port -> Date-equivalent line or empty
    E=$(
        ( $BB printf '\x1b'; $BB dd if=/dev/zero bs=1 count=47 2>/dev/null ) |
            $BB nc -u -w 4 "$1" "$2" |
            $BB dd bs=1 skip=40 count=4 2>/dev/null |
            $BB od -An -tx1 | $BB tr -d ' \n'
    )
    [ "${#E}" -eq 8 ] || return 1
    $BB awk -v h="$E" 'BEGIN{
        n=0; for (i=1;i<=8;i++){n=n*16+index("0123456789abcdef",substr(h,i,1))-1}
        printf "Date: NTP %d\n", n-2208988800 }'
}

wait_route() {  # wait for a default route, ~2 min max
    i=0
    while [ $i -lt 40 ]; do
        if $BB route -n 2>/dev/null | $BB grep -q "^0.0.0.0"; then return 0; fi
        sleep 3; i=$((i+1))
    done
    return 1
}

# tries all sources, echoes an epoch or returns non-zero
measure() {
    local D E
    for port in 9090 80 8080; do
        D=$(http_date "$GW" "$port" /version)
        E=$(date_to_epoch "$D")
        if [ "${#E}" -ge 10 ] && [ "$E" -gt 1577836800 ] 2>/dev/null; then
            echo "$E (gateway :$port $(echo $D | $BB sed 's/^ *Date: *//'))"
            return 0
        fi
        D=$(http_date "$GW" "$port" /)
        E=$(date_to_epoch "$D")
        if [ "${#E}" -ge 10 ] && [ "$E" -gt 1577836800 ] 2>/dev/null; then
            echo "$E (gateway / :$port $(echo $D | $BB sed 's/^ *Date: *//'))"
            return 0
        fi
    done
    D=$(ntp_date "$GW" 123)
    E=$($BB echo "$D" | $BB sed "s/Date: NTP //")
    if [ "${#E}" -ge 10 ] && [ "$E" -gt 1577836800 ] 2>/dev/null; then
        echo "$E (gateway ntp)"
        return 0
    fi
    return 1
}

i=0
MAX=240
while [ $i -lt $MAX ]; do
    if ! $BB route -n 2>/dev/null | $BB grep -q "^0.0.0.0"; then
        sleep 5; i=$((i+1)); continue
    fi
    [ -z "$GW" ] && GW=$($BB route -n | $BB awk '$1=="0.0.0.0"{print $2; exit}')
    OUT=$(measure)
    RC=$?
    if [ $RC -eq 0 ]; then
        E=$($BB echo "$OUT" | $BB sed 's/ .*//')
        ORIGIN=$($BB echo "$OUT" | $BB sed 's/^[0-9]\+ //')
        NOW=$($BB date -u +%s)
        if [ $((E - NOW)) -gt 60 ] || [ $((NOW - E)) -gt 60 ]; then
            if [ "$DRY" = "1" ]; then
                echo "DRY have $E via $ORIGIN (drift $((E - NOW))s)"
            else
                if $BB date -s "@$E" >/dev/null 2>&1; then
                    log "clock set $E via $ORIGIN"
                    exit 0
                fi
                L=$($BB date -d "@$E" "+%Y%m%d%H%M.%S" 2>/dev/null)
                if $BB date -u -s "$L" >/dev/null 2>&1; then
                    log "clock set (compact) $E via $ORIGIN"
                    exit 0
                fi
                log "set failed: want $E, have $NOW"
            fi
            exit 0
        fi
        echo "clock already within 60s (via $ORIGIN)"
        exit 0
    fi
    sleep 5; i=$((i+1))
done
log "gave up after $MAX polls"
exit 1
