#!/bin/bash
# 2-11-13 / dosman / pull linksys dhcp table and do things with it
#                    Command line client to see what devices are on the network that the linksys
#		     knows about. -html flag generates htmlified results. -count flag attempts
#		     to show number of *NEW* devices on the network (within the last day).
#
# 3-27-14 / dosman / added $LOG so we can keep some record of systems on our network over time
#		     only updates log with -html flag, assumes cron is calling it
#
##############################################################################

# Linksys WRT54G
ROUTER=192.168.1.1
USER=username
PASS=password

##############################################################################
# Device count options

# The -count flag causes the script to output a single number, the number of
# *new* active devices on the network. The intent is to provide the likely number of
# humans in the space, for each new device that shows up on the wifi or hardline
# it becomes easier to assume humans are in the space. The router's DHCP table is 
# pulled, then each device is pinged and if still alive it's counted. If it's in 
# the IGNORE list it is skipped (permenant devices always on the network like 
# network printers and servers).

# This can be an ip, hostname, or mac (lower case hex), pipes between entries
IGNORE=""

# This next part tries to prevent a new device which has been left in the space permenantly from
# throwing off the count (assuming most people will forget to update the IGNORE list
# when a device gets added to the sapce).

# After a device has been on the network for PERMSECS seconds it is assumed to be
# left in the space permenently without a human so we begin ignoring the device in the -count
# output. If the device then goes away, it's IGNORECACHE entry is cleared so if it shows up again
# it will be treated like any new device on the network.
PERMSECS=86400
IGNORECACHE=/tmp/dhcp.ignore.cache
LOG=/var/log/dhcpclients-linksys.log

# Keep track of http requests, Linksys webserver locks up after around 576 or so (48 hours of requests every 5 minutes)
#PULLCOUNT=/tmp/linksys.dhcp.pullcount
#PULLCOUNT=`test -e $PULLCOUNT && grep -v "^#" $PULLCOUNT`
#PULLMAX=576

##############################################################################
TMP1=/tmp/$$linksys_clients1.tmp
TMP2=/tmp/$$linksys_clients2.tmp
TMP3=/tmp/$$linksys_clients3.tmp
TMP4=/tmp/$$linksys_clients4.tmp
TMP5=/tmp/$$linksys_clients5.tmp
TMP6=/tmp/$$linksys_clients6.tmp
TMP7=/tmp/$$linksys_clients7.tmp
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

restart_linksys() {
echo "Restarting $ROUTER..."
logger -t wintermute "Resetting $ROUTER..."
# Undocumented reset page on the first link (requires confirmation click), second link does it in one step
#wget --user=$USER --password=$PASS -O $TMP1 http://${ROUTER}/Reset.htm > /dev/null 2>&1
wget --user=$USER --password=$PASS -O $TMP1 --post-data 'submit=Yes' "http://${ROUTER}/reboot.tri?"
}
##############################################################################

if [[ $1 == "-html" || $2 == "-html" ]];then
	HTML=1
elif [[ $1 == "-restart" ]];then
	restart_linksys
	cleanup
	exit
elif [[ $1 == "-count" || $2 == "-count" ]];then
	COUNT=0
elif [[ $1 == "-speak" || $1 == "-speak" ]];then
	SPEAK=1
elif [[ $1 == "-help" || $1 == "--help" || $1 == "--?" || $1 == "-?" || $1 == "-h" || $1 == "--h" ]];then
	echo "Usage for $0"
	echo "Shows DHCP clients which have active leases"
	echo ""
	echo "-html	Generate HTML output"
	echo "-count	Report number of active/pingable clients, minus clients in IGNORE variable in script"
	#echo "-speak	Can be used with -html and -count, calls Wintermute and annunciates new devices on the network"
	echo "-restart	Restart the linksys AP, required daily when automatically pulling info from the web interface"
	exit
fi

make_it_talk() {
	# Call out all new devices on the network over Wintermute's audio output
	: continue
}

clear_stale_cache() {
# Clear out devices in the cache ignore file which no longer have leases
for cachemac in `cat $IGNORECACHE | awk '{print $2}'`;do
	for dhcpmac in `cat $TMP6`;do
		if [[ $cachemac == $dhcpmac ]];then
			# The DHCP table still has this mac listed, keep ignoring it until it goes unlisted from the table
			matchfound=1
		fi
	done
	if [[ -z $matchfound ]];then
		grep -v "$cachemac" $IGNORECACHE > $TMP7
		mv $TMP7 $IGNORECACHE
	else
		unset matchfound
	fi
done
}

##############################################################################
wget --user=$USER --password=$PASS -O $TMP1 http://${ROUTER}/DHCPTable.htm > /dev/null 2>&1
if [[ $? -gt 0 ]];then
	echo "Error pulling dhcp client info from router"
	logger -t linksys-clients "Error pulling dhcp client info from router"
	cleanup
	exit 1
fi
if [[ -n $HTML ]];then
	echo "<html><head><title>CURRENT DHCP CLIENTS</title><META HTTP-EQUIV=\"REFRESH\" content=\"120\"><META HTTP-EQUIV=\"EXPIRES\" content=\"Sat, 01 Jan 2000 00:00:00 GMT\"></head><body><h2>CURRENT DHCP CLIENTS</h2>`date`<br><br><table height=108 cellSpacing=1 width=673 border=1><tr><th>Hostname</th><th>IP</th><th>MAC</th><th>DHCP Lease Expires</th></tr>"
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
	HOSTNAME=`head -2 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	if [[ -z $HOSTNAME ]];then
		HOSTNAME="n/a"
	fi
	IP=`head -3 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	MAC=`head -4 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	EXPIRE=`head -5 $TMP5 | tail -1 | awk -F\> '{print $2}' | awk -F\< '{print $1}'`
	# Save this entry for processing by clear_stale_cache()
	#echo "${IP},${MAC},${EXPIRE}" >> $TMP6
	echo "${MAC}" >> $TMP6

	if [[ -n $HTML ]];then
		echo "<tr><td>$HOSTNAME</td><td>$IP</td><td>$MAC</td><td>$EXPIRE</td></tr>"
		echo "`date`,${HOSTNAME},${IP},${MAC},${EXPIRE}" >> $LOG
	elif [[ -n $COUNT ]];then
		echo "$HOSTNAME $IP $MAC" | egrep -v "$IGNORE" > /dev/null 2>&1
		if [[ $? -eq 0 ]];then
			ping -c 1 $IP > /dev/null 2>&1
			if [[ $? -eq 0 ]];then
				CACHE=`grep $MAC $IGNORECACHE 2>/dev/null`
				if [[ -n $CACHE ]];then
					DATE=`date +%s`
					cDATE=`echo $CACHE | awk '{print $1}' `
					diffDATE=`expr $DATE - $cDATE`
					# If MAC has been on our network (and pingable) for less than 24 hours count it, if over ignore it
					if [[ $diffDATE -lt $PERMSECS ]];then
						#echo "DATE $DATE / cDATE $cDATE / diffDate $diffDATE"
						COUNT=`expr $COUNT + 1`
					fi
				else
					echo "`date +%s` $MAC" >> $IGNORECACHE
					COUNT=`expr $COUNT + 1`
				fi
			else
				# Clear the cache entry for this system if it exists
				# Problem: was causing devices which go on and off the network frequently during the evening to be frequently re-announced, don't clear the entry here...
				CACHE=`grep $MAC $IGNORECACHE 2>/dev/null`
				if [[ -n $CACHE ]];then
					grep -v $CACHE $IGNORECACHE > $TMP6
					mv $TMP6 $IGNORECACHE
				fi
			fi
		fi
	else
		echo "HOSTNAME $HOSTNAME | IP $IP | MAC $MAC | LEASE EXPIRES $EXPIRE"
	fi
done

# Clear clients from the $IGNORECACHE once they disappear from the dhcp table
#clear_stale_cache

if [[ -n $HTML ]];then
	echo "</table></body></html>"
elif [[ -n $COUNT ]];then
	echo $COUNT
fi

cleanup
