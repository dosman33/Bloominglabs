#!/bin/bash
# 02-11-13 / dosman / Pull Linksys-WRT54G dhcp table and do things with it
# 04-30-15 / dosman / Based on linksys script, says a message if someone's device is found active and pingable on the network
#
##############################################################################

# Linksys WRT54G
ROUTER=192.168.1.1
USER=
PASS=

LOG=/var/log/wakeup.log

# Space delimited list, each part is name,mac,message_block
MACLIST="Timmy,88:5c:30:2a:b3:00,HEYTHERE"

# These messages are randomly selected based on the message delimiter specified by "message_block" above
#HEYTHERE:Hey good to see you again
#HEYTHERE:Welcome back

#LATEDUES:Your dues are late, get paid up

##############################################################################

TMP1=/tmp/$$wakeup_message1.tmp
TMP2=/tmp/$$wakeup_message2.tmp
TMP3=/tmp/$$wakeup_message3.tmp
TMP4=/tmp/$$wakeup_message4.tmp
TMP5=/tmp/$$wakeup_message5.tmp
TMP6=/tmp/$$wakeup_message6.tmp
TMP7=/tmp/$$wakeup_message7.tmp
cleanup() {
        rm -rf $TMP1
        rm -rf $TMP2
        rm -rf $TMP3
        rm -rf $TMP4
        rm -rf $TMP5
        rm -rf $TMP6
        rm -rf $TMP7
}
trap 'echo "--Interupt signal detected, cleaning up and exiting" ; cleanup ; exit 1' 2 3   #SIGINT SIGQUIT

##############################################################################

if [[ $1 == "-help" || $1 == "--help" || $1 == "--?" || $1 == "-?" || $1 == "-h" || $1 == "--h" ]];then
	echo "Usage for $0"
	echo "Identify if a mac address is active on our network and if so, play them an audio message"
	echo "MAC address table is coded inside the script, just schedule script to run from cron"
	exit
fi

rand() {
        #spits out a random number, requires an upper bound number as input
        typeset upper=$1
        typeset RNUM=" "
        RNUM=`awk -vu=$upper 'BEGIN {
                srand();
                printf( "%0.0f\n", rand() * u );
        }'`
        if [[ $RNUM -eq 0 ]];then
                ((RNUM=RNUM + 1))
        fi
        echo $RNUM
}

announcer() {
	typeset delim=$1
	typeset name=$2
	grep "^#${delim}" $0 > $TMP7
        len=`wc -l $TMP7 | awk '{print $1}'`
        line=`rand $len` # pick a random line from the list of messages
	typeset MESSAGE=`head -$line $TMP7 | tail -1 | sed "s/#${delim}://g" | sed "s/\%NAME/${name}/"`
	#echo "b double e double r u n beer run" | espeak -s 50 --stdin > /dev/null 2>&1
	echo "${MESSAGE}" | espeak -s 50 --stdin > /dev/null 2>&1
	logit
}

logit() {
	echo "`date` - wakeup announced for $NAME - $MESSAGE" >> $LOG
	#echo "`date` - $delim announced for $NAME - $MESSAGE" | mailx -s "Wakeup event" dosman@bloominglabs.org
}

##############################################################################

wget --user=$USER --password=$PASS -O $TMP1 http://${ROUTER}/DHCPTable.htm > /dev/null 2>&1
if [[ $? -gt 0 ]];then
	echo "Error pulling dhcp client info from router"
	logger -t linksys-clients "Error pulling dhcp client info from router"
	cleanup
	exit 1
fi

egrep "<tr|<td" $TMP1 > $TMP2
# top lines
grep -n "<tr" $TMP2 | awk -F: '{print $1}' > $TMP3
# bot lines
grep -n "<td><input type" $TMP2 | awk -F: '{print $1}' > $TMP4

for top in `cat $TMP3`;do
	line=`grep -n "^${top}$" $TMP3 | awk -F: '{print $1}'`
	bot=`head -${line} $TMP4 | tail -1`
	#echo "line = $line / top = $top / bot = $bot"
	sed -n "${top},${bot}p" $TMP2 > $TMP5
	#HOSTNAME=`head -2 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	#if [[ -z $HOSTNAME ]];then
	#	HOSTNAME="n/a"
	#fi
	IP=`head -3 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	MAC=`head -4 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	#echo "IP $IP / MAC $MAC"

	for namemac in $MACLIST;do
		NAME=`echo $namemac | awk -F, '{print $1}'`
		testmac=`echo $namemac | awk -F, '{print $2}'`
		delim=`echo $namemac | awk -F, '{print $3}'`
		#echo "NAME $NAME / testmac $testmac / delim $delim"
		if [[ $testmac == $MAC ]];then
			ping -c 1 $IP > /dev/null 2>&1
			if [[ $? -eq 0 ]];then
				# We have a match, this person's device is in the space right now
				announcer $delim $NAME
			fi
		fi
		unset testmac NAME
	done
done
cleanup
