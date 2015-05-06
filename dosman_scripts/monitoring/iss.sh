#!/bin/bash
# 2013-12-11 / dosman / identify when ISS is within a short period of going overhead
#############################################################################################

# Minutes before ISS crossing to notify on
CHECKTIME=5
RECIPIENTS=root

LAT="39.1653"
LONG="-86.5264"
LOC="Bloomington"
# Altitude in meters
ALT="234"
TZ="EST"

# ISS
SATID="25544"

# Only pull the file once daily
OUT=/tmp/heavensabove.txt

#############################################################################################

URL="http://www.heavens-above.com/PassSummary.aspx?satid=${SATID}&lat=${LAT}&lng=${LONG}&loc=${LOC}&alt=${ALT}&tz=${TZ}"

MONTH=`date +%b`
DAY=`date +%d`
HOUR=`date +%H`
MIN=`date +%M`
TIME=`expr $HOUR \* 60`
TIME=`expr $TIME + $MIN`

GAG=/tmp/heavensabove.gag

TMP1=/tmp/$$_iss-1.tmp
TMP2=/tmp/$$_iss-2.tmp
cleanup() {
        rm -rf $TMP1
        rm -rf $TMP2
}
trap 'echo "--Interupt signal detected, cleaning up and exiting" ; cleanup ; exit 1' 2 3        #SIGINT SIGQUIT

#############################################################################################

# Only pull the ISS locations once daily if needed
if [[ -e $OUT ]];then
	FMONTH=`ls -l $OUT | awk '{print $6}'`
	FDAY=`ls -l $OUT | awk '{print $7}'`
else
	FMONTH=0
	FDAY=0
fi

if [[ $FMONTH != $MONTH || $FDAY != $DAY ]];then
	wget -O $OUT "$URL" > /dev/null 2>&1
	# It's a new day, clear any existing GAG file
	rm -rf $GAG
fi

ISSDATE=`grep "clickableRow lightrow" $OUT | head -1 | awk -F\> '{print $4}' | awk -F\< '{print $1}'`
ISSTIME=`grep "clickableRow lightrow" $OUT | head -1 | awk -F\> '{print $9}' | awk -F\< '{print $1}'`

ISSMONTH=`echo $ISSDATE | awk '{print $2}'`
ISSDAY=`echo $ISSDATE | awk '{print $1}'`

ISSHOUR=`echo $ISSTIME | awk -F: '{print $1}'`
ISSMIN=`echo $ISSTIME | awk -F: '{print $2}'`
ISSTIME=`expr $ISSHOUR \* 60`
ISSTIME=`expr $ISSTIME + $ISSMIN`

if [[ $MONTH == $ISSMONTH && $DAY == $ISSDAY ]];then
	# Date matches, now check time and notify as appropriate
        timeDiff=`expr $ISSTIME - $TIME`
	#echo "timeDiff = $timeDiff"

	if [[ $timeDiff -lt 0 ]];then
		rm -rf $GAG
		exit
	fi

	if [[ $timeDiff -le $CHECKTIME && ! -e $GAG ]];then
		#echo "The I S S will cross over head in $timeDiff minutes" | mail -s "ISS" $RECIPIENTS
		echo "The I S S will cross over head in $timeDiff minutes" | /usr/bin/festival --tts
		touch $GAG
	fi
fi



