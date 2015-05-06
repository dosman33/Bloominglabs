#!/bin/bash
# 2-11-13 / dosman / pull linksys dhcp table and do things with it
#                    Command line client to see what devices are on the network that the linksys
#		     knows about. -html flag generates htmlified results. -count flag attempts
#		     to show number of *NEW* devices on the network (within the last day).
##############################################################################

# Linksys WRT54G
#ROUTER=192.168.1.1
#USER=
#PASS=

INPUT=/home/dosman/public_html/dhcp.html
LINKSYS_SCRIPT=/home/dosman/bin/linksys_clients.sh
# clients to be ignored
IGNORE=`grep "^IGNORE" $LINKSYS_SCRIPT | awk -F= '{print $2}'`
# dhcp clients who have already been announced
IGNORECACHE=/tmp/dhcp.announce.ignore.cache

WM=/usr/local/wintermute/wm

##############################################################################
#TMP1=/tmp/$$dhcp_clients_announce1.tmp
#cleanup() {
#        rm -rf $TMP1
#}
#trap 'echo "--Interupt signal detected, cleaning up and exiting" ; cleanup ; exit 1' 2 3   #SIGINT SIGQUIT

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

for client in `grep "^<tr>" $INPUT | awk -F\> '{print $3}' | awk -F\< '{print $1}' | tr " " "~"`;do
	client=`echo $client | tr "~" " "`
	cip=`grep $client $INPUT | awk -F\> '{print $5}' | awk -F\< '{print $1}'`
	echo $IGNORE | grep $client > /dev/null 2>&1
	RET1=$?
	grep $client $IGNORECACHE > /dev/null 2>&1
	RET2=$?
	if [[ $RET1 -eq 0 || $RET2 -eq 0 ]];then
		continue
	elif [[ $client == "n/a" ]];then
		continue
	else
		ping -c 1 $cip > /dev/null 2>&1
		if [[ $? -eq 0 ]];then
			#$WM entry $client

		        # Droid phones have name strings like this: "android-9d524187e577cf91" which is very annoying to hear over and over
		        echo "$HOSTNAME" | grep -i android > /dev/null 2>&1
		        if [[ $? -eq 0 ]];then
       		        	$client="android dash blah blah blah"
		        fi
			echo "New device on network, $client" | sed 's/[Ii][Pp][Hh][Oo][Nn][Ee]/i phone/g' | /usr/bin/festival --tts
			echo "$client" >> $IGNORECACHE
		fi
	fi
done

# Clear out stale cache file entries
clearcache() {
TMP1=/tmp/$$_blah1
for client in `cat $IGNORECACHE`;do
	cip=`grep $client $INPUT | awk -F\> '{print $5}' | awk -F\< '{print $1}'`
	ping -c 1 $cip > /dev/null 2>&1
	if [[ $? -gt 0 ]];then
		grep -v $client $IGNORECACHE > $TMP1
		mv $TMP1 $IGNORECACHE
	fi
done
}
# cheap hack to only clear the cache at 6am to stop reannouncing devices which continously pop on and off the network
# Will reannounce any devices still on the network at 6am which renew their dhcp leases after the 5am linksys restart
if [[ `date +%H` == "06" ]];then
	clearcache
fi
#cleanup
