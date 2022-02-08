#!/bin/bash

# This script depends on ts for logging.  'apt install moreutils' under Debian

B2_VARS="/etc/restic-b2stuff"

export B2_ACCOUNT_ID="$(sed '1q;d' $B2_VARS)" # Application key keyID
export B2_ACCOUNT_KEY="$(sed '2q;d' $B2_VARS)" # Application key keyName
export RESTIC_PASSWORD_FILE="/etc/restic-password"

RESTIC_REPO="$(sed '3q;d' $B2_VARS)" # B2 bucket name
RESTIC_CMD="/usr/bin/restic -v -r $RESTIC_REPO"
TS_DATE="[%Y-%m-%d %H:%M:%S]"
RETENTION="30d"
EXCLUDES="/opt/restic/excludes"
RESTIC_LOG="/var/log/restic.log"

for pid in $(pidof -x restic.sh); do
    if [ $pid != $$ ]; then
        echo "FAIL: Process is already running with PID $pid"
        exit 1
    fi
done

if [ ! -z "$1" ]; then
	$RESTIC_CMD $1
	exit $?
fi

apt list --installed 2>/dev/null > /root/installed_packages

# Folders of interest (absolute paths, please)
FOI=(
     "/home"
     "/etc"
     "/var"
     "/srv"
     "/root"
     )

TOTAL=${#FOI[@]}
CNT=0

for i in "${FOI[@]}"; do
	((CNT++))
	echo "Starting backup of $i ($CNT of $TOTAL)" | ts "$TS_DATE" >> $RESTIC_LOG
	$RESTIC_CMD backup $i --exclude-file=$EXCLUDES 2>&1 | ts "$TS_DATE" >> $RESTIC_LOG
	echo "Return code for home backup was $?" | ts "$TS_DATE" >> $RESTIC_LOG
	echo "Finished backup of $i" | ts "$TS_DATE" >> $RESTIC_LOG
done

# Prune snapshots
$RESTIC_CMD forget --keep-within $RETENTION --prune 2>&1 | ts "$TS_DATE" >> $RESTIC_LOG
