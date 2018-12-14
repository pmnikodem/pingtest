#!/bin/bash

set -e
TARGETFILE=targets
FPING=`which fping`
TRACEROUTE=`which traceroute`
PRINTF=`which printf`
set +e

function pingtest()
{
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
		$FPING -c3 $TARGET &>/dev/null
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
		$FPING -c3 $TARGET &>/dev/null
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
}

while true
do
	while read TARGET
	do
		pingtest $TARGET &
	done < $TARGETFILE
	sleep 5
done
