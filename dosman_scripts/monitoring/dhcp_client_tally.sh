#!/bin/bash
# 03-27-14 / dosman / generate an tally list of dhcp clients from recent log for web page
#####################################################################################

LOG=/var/log/dhcpclients-linksys.log
#OUT=/home/dosman/public_html/dhcp-client-history.html
OUT=/var/www/reports/dhcp-client-history.html

#####################################################################################
TMP1=/tmp/$$_dhcp-tally-1.tmp
cleanup() {
        rm -rf $TMP1
}
trap 'echo "--Interupt signal detected, cleaning up and exiting" ; cleanup ; exit 1' 2 3        #SIGINT SIGQUIT
#####################################################################################

echo "<html><head><title>DHCP CLIENT HISTORY LOG</title><META HTTP-EQUIV=\"REFRESH\" content=\"120\"><META HTTP-EQUIV=\"EXPIRES\" content=\"Sat, 01 Jan 2000 00:00:00 GMT\"></head><body>" > $OUT
echo "<h2>DHCP Client History</h2>`date`<br><br>" >> $OUT
echo "<table height=108 cellSpacing=1 width=850 border=1><tr><th>Last Seen</th><th>Hostname</th><th>IP</th><th>MAC</th><th>Last DHCP Lease Expiration</tr>" >> $OUT

awk -F, '{print $4}' $LOG | sort | uniq > $TMP1
for line in `cat $TMP1`;do #$line should be a MAC but thats not important
	printf "<tr><td>" >> $OUT
	grep $line $LOG | tail -1 | sed 's/,/\<\/td>\<td>/g' >> $OUT
	#grep $line $LOG | tail -1 | sed 's/,/\<\/td>\<td>/g'
	echo "</td></tr>" >> $OUT
done

echo "</table></body></html>" >> $OUT

cleanup
