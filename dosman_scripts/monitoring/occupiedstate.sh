#!/bin/bash
# 05-05-2015 / dosman / read inputs and provide a 1 or 0 for occupied status
######################################################################################################

LOG=/var/log/occupied.log
STATE=/tmp/occupied_state.txt

# Path for sensor scripts
BINPATH=/home/pi/bin

HTMPATH=/var/www/reports
HTMLOUT=${HTMLPATH}/spacestatus.html

######################################################################################################
TMP1=/tmp/$$_occupied_status01.tmp
TMP2=/tmp/$$_occupied_status02.tmp
TMP3=/tmp/$$_occupied_status03.tmp
TMP4=/tmp/$$_occupied_status04.tmp
TMP5=/tmp/$$_occupied_status05.tmp

cleanup() {
        rm -rf $TMP1
        rm -rf $TMP2
        rm -rf $TMP3
        rm -rf $TMP4
        rm -rf $TMP5
}
trap 'echo "--Interupt signal detected, cleaning up temp files and exiting... " ; cleanup ; exit 1' 2 3

score_keeper() {
	SCORE=`expr $SCORE + $NETWORKCOUNT`
	SCORE=`expr $SCORE + $LIGHTS`
	SCORE=`expr $SCORE + $MOTION`
	SCORE=`expr $SCORE + $AUDIO`
	SCORE=`expr $SCORE + $DOOR`
	SCORE=`expr $SCORE + $RFID`
}

read_networkcount() {
	typeset NETCOUNT=`${BINPATH}/linksys_clients.sh -count`
	return $NETCOUNT
}

read_lights() {
	# Light Level: 64.1666666667
	typeset LON=15
	typeset LIGHTVALUE=`${BINPATH}/bh1750.py | awk -F: '{print $NF}' | awk -F. '{print $1}' | tr -d " "`
	if [[ $LIGHTVALUE -ge $LON ]];then
		return 1
	else
		return 0
	fi
}

MOTIONLOG01=/var/log/motion01.log
# Seconds since last motion event detected to consider a hit
MOTIONDELAY=300

read_motion01() {
	typeset NOW=`date +%s`
	#typeset LINE=`tail -1 $MOTIONLOG01`
	typeset LINE=`grep "motion detected" $MOTIONLOG01 | tail -1`
	if [[ -n $LINE ]];then
		typeset MOEPOC=`echo $LINE | awk '{print $3}'`
		MOEPOC=`echo $MOEPOC | awk -F. '{print $1}'`
		typeset var=`expr $NOW - $MOEPOC`
		if [[ $var -le $MOTIONDELAY ]];then
			return 1
		else
			return 0
		fi
	else
		# We have no previous motion events to go on, return 0
		return 0
	fi

}

read_audio() {
	return 0
}

read_door() {
	return 0
}

read_rfid() {
	return 0
}

######################################################################################################

ignore() {
# Initialize our state
if [[ ! -e "$STATE" ]];then
	echo "NETWORKCOUNT=0
LIGHTS=0
MOTION=0
AUDIO=0
DOOR=0
RFID=0" > $STATE

	NETWORKCOUNT=0
	LIGHTS=0
	MOTION=0
	AUDIO=0
	DOOR=0
	RFID=0
	SCORE=0
else
	# We have a previous state, import it
	for line in `cat $STATE`;do
		event=`echo $line | awk -F= '{print $1}'`
		state=`echo $line | awk -F= '{print $2}'`
		if [[ $event == "NETWORKCOUNT" || $event == "LIGHTS" || $event == "MOTION" || $event == "AUDIO" || $event == "DOOR" || $event == "RFID" ]];then
			eval ${event}=${state}
		fi
	done
	unset event
	SCORE=0
	score_keeper
fi
}

######################################################################################################

NETWORKCOUNT=0
LIGHTS=0
MOTION=0
AUDIO=0
DOOR=0
RFID=0
SCORE=0

read_lights
LIGHTS=$?
read_motion01
MOTION=$?
read_networkcount
NETWORKCOUNT=$?
score_keeper

echo "NETWORKCOUNT = $NETWORKCOUNT / LIGHTS = $LIGHTS / MOTION = $MOTION / AUDIO = $AUDIO / DOOR = $DOOR / RFID = $RFID / SCORE = $SCORE"


if [[ $SCORE -gt 0 ]];then
	echo "Space occupied, score is $SCORE"
else
	echo "Space unoccupied, score is $SCORE"
fi

######################################################################################################
