#!/bin/bash

if [ $# -eq 0 ]; then
	shopt -s nullglob
	PINGTESTLOGS=(./logs/*.log)
else
	PINGTESTLOGS=("$@")
fi

for LOGFILE in "${PINGTESTLOGS[@]}"
do
	if [ ! -f "$LOGFILE" ]; then
		echo "Error: file '$LOGFILE' not found."
		exit 1
	fi
done

set -e
BADMSG="lost"
BADSTATUS="0"
COLUMNHEAD="STATUS,EPOCH"
DATEOUT="+%s"
GOODMSG="reconnected"
GOODSTATUS="1"
PRINTF="$(which printf)"
set +e

function getEventTimes()
{
	CSVFILE="$2"
	if (echo "$1" | grep -q "$BADMSG"); then
		THISDATE=$(echo "$1" | grep "$BADMSG" | cut -d "-" -f 1)
		THISSEC=$(date --date="$THISDATE" "$DATEOUT")
		$PRINTF '%s,%s\n' $BADSTATUS $THISSEC >> "$CSVFILE"
	elif (echo "$1" | grep -q "$GOODMSG"); then
		THISDATE=$(echo "$1" | grep "$GOODMSG" | cut -d "-" -f 1)
		THISSEC=$(date --date="$THISDATE" "$DATEOUT")
		$PRINTF '%s,%s\n' $GOODSTATUS $THISSEC >> "$CSVFILE"
	fi
}

for LOGFILE in "${PINGTESTLOGS[@]}"
do
	CSVFILE="$(basename -s '.log' $LOGFILE).csv"
	echo "Processing '$LOGFILE' with output to '$CSVFILE'."
	echo "$COLUMNHEAD" > "$CSVFILE"
	while read LINE
	do
		getEventTimes "$LINE" "$CSVFILE"
	done < "$LOGFILE"
done
exit 0
