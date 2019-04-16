#!/bin/bash

if [ $# -eq 0 ]; then
	TIMEOUT=200
else
	TIMEOUT=$1
fi

case $TIMEOUT in
	''|*[!0-9]*) echo Error: timeout must be integer; exit 1 ;;
	*) ;;
esac

set -e
TARGETFILE=targets
FPING="`which fping` -q -t $TIMEOUT -p200 -c5"
TRACEROUTE=`which traceroute`
PRINTF=`which printf`
set +e

function pingtest()
{
	{
	flock -n 99 || { exit 1; }

	TARGET=$1
	LOGFILE=logs/$TARGET.log
	RESFILE=logs/$TARGET-result.txt
	touch $RESFILE
	#export TZ='America/Chicago'
	export TIMESTAMP=`date +%s`
	LASTCHANGE=`tail -n 1 $RESFILE`

	grep -q -i failed $RESFILE

	if [ $? = 0 ]; then
		# if last result was failed, attempt to reconnect:
		$FPING $TARGET #&>/dev/null
		# if reconnect succeeded, log to file and record length of outage:
		if [ $? = 0 ]; then
			if [ ! `grep -i succeeded $RESFILE` ]; then
				$PRINTF "`date -d @$TIMESTAMP`" >> $LOGFILE
				let "TIMEDIFF = $TIMESTAMP - $LASTCHANGE"
				$PRINTF ' - reconnected after %s seconds\n' $TIMEDIFF >> $LOGFILE
			fi
			echo 'succeeded' > $RESFILE
			echo $TIMESTAMP >> $RESFILE
		fi
	elif [ $? != 0 ]; then
		# if last result was succeeded, test whether we are still OK:
		$FPING $TARGET #&>/dev/null
		# if current test failed, log to file and record timestamp of initial failure:
		if [ $? != 0 ]; then
			echo 'failed' > $RESFILE
			echo $TIMESTAMP >> $RESFILE
			echo '' >> $LOGFILE
			$PRINTF "`date -d @$TIMESTAMP`" >> $LOGFILE
			$PRINTF ' - lost connection to %s\n' $TARGET >> $LOGFILE
			$PRINTF '=%.0s' {1..70} >> $LOGFILE
			$PRINTF '\n' >> $LOGFILE
			$TRACEROUTE -I $TARGET -m12 -I >> $LOGFILE
			$PRINTF '=%.0s' {1..70} >> $LOGFILE
			$PRINTF '\n' >> $LOGFILE
		fi
	fi

	} 99>.lock/$TARGET.lock
}

while true
do
	while read TARGET
	do
		pingtest $TARGET &
	done < $TARGETFILE
	sleep 5
done
