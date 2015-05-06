#!/bin/bash
# 10-20-2014 / dosman / Digests RFID logs and decodes RFID fob #'s to usernames
# 01-29-2015 / dosman / Picks up "255" user disabled mask messages now (Best), does both "reader" and "granted" messages 
#                       which makes it easier to tell what is going on when things are messed up or complicated
# 02-08-2015 / dosman / Added "exit button pressed" logging

##########################################################################################################################

# Web login:
RFID_LOGIN=
RFID_PASSWD=
RFIDURL=

# SSH login:
RFIDHOST=
RFID_SSH_UNAME=
RFID_LOG=

HTMLOUT=/var/www/rfid/file.html
##########################################################################################################################

COOKIES=/dev/shm/$$_blabs_rfid00.tmp
WGETFLAGS="--no-check-certificate --load-cookies $COOKIES --save-cookies $COOKIES --keep-session-cookies"

RFIDTMP1=/dev/shm/$$_blabs_rfid01.tmp
RFIDTMP2=/dev/shm/$$_blabs_rfid02.tmp
RFIDTMP3=/dev/shm/$$_blabs_rfid03.tmp
RFIDTMP4=/dev/shm/$$_blabs_rfid04.tmp
RFIDTMP5=/dev/shm/$$_blabs_rfid05.tmp

OUT=/dev/shm/$$_blabs_rfid.out

cleanup() {
        rm -rf $OUT
        rm -rf $RFIDTMP1
        rm -rf $RFIDTMP2
        rm -rf $RFIDTMP3
        rm -rf $RFIDTMP4
        rm -rf $RFIDTMP5
        rm -rf $COOKIES
}
trap 'echo "--Interupt signal detected, cleaning up temp files and exiting... " ; cleanup ; exit 1' 2 3

#TODAYMODAY=`date +%m-%d`
#TODAYYEAR=`date +%Y`
#LASTYEAR=`expr $TODAYYEAR - 1`
#TODAY="${TODAYYEAR}-${TODAYMODAY}"
#PRIOR="${LASTYEAR}-${TODAYMODAY}"
#echo "TODAY = $TODAY / PRIOR = $PRIOR"

if [[ $1 == "-h" || $1 == "--h" || $1 == "-?" || $1 == "--?" ]];then
	echo "Usage:"
	echo "$0 	| Lists RFID access log with real names"
	echo "$0 -html  | Outputs html version"
	echo ""
	exit
elif [[ $1 == "-html" ]];then
	# Enable HTML output
	HTML=1
fi

rfid_name_lookup() {
	# Doing this the awkward way since comment fields can contain old tag id's for former members
	typeset rfid_line=$1
	if [[ -n $rfid_line ]];then
		typeset firstname=`head -$rfid_line $RFIDTMP3 | tail -1 | awk -F\> '{print $12}' | awk -F\< '{print $1}'`
		typeset lastname=`head -$rfid_line $RFIDTMP3 | tail -1 | awk -F\> '{print $14}' | awk -F\< '{print $1}'`
		if [[ "$firstname" == "&nbsp;" ]];then
			#firstname=n/a
			firstname="$myRFID"
			lastname=" "
		fi
		if [[ "$lastname" == "&nbsp;" ]];then
			#firstname=n/a
			firstname="$myRFID"
			lastname=" "
		fi
	else
		# The fob id is not in our database - most likely from testing a new fob before programming it in
		#firstname="n/a"
		firstname="$myRFID"
		lastname=" "
	fi
	echo "$firstname $lastname"
}
##########################################################################################################################

echo "- Connecting to RFID admin server..."
# Obtain a session token
wget -O $RFIDTMP1 --no-check-certificate --save-cookies $COOKIES --keep-session-cookies $RFIDURL > /dev/null 2>&1
TOKENNAME=`grep "form action" $RFIDTMP1 | awk '{print $7}' | awk -F\' '{print $2}' | tr -d "'"`
TOKENVALUE=`grep "form action" $RFIDTMP1 | awk '{print $8}' | awk -F\' '{print $2}' | tr -d "'"`

echo "- Logged in, connecting to first page..."
# Login - referer is checked and must be set
wget -O $RFIDTMP2 ${WGETFLAGS} --post-data "${TOKENNAME}=${TOKENVALUE}&username=${RFID_LOGIN}&password=${RFID_PASSWD}&this_is_the_login_form=1&next=/wsgi-scripts/admin/" --referer="${RFIDURL}" "${RFIDURL}" > /dev/null 2>&1

echo "- Retreiving user list..."
# Get RFID member list - output is $RFIDTMP3
wget -O $RFIDTMP3 ${WGETFLAGS} --post-data "${TOKENNAME}=${TOKENVALUE}&this_is_the_login_form=1&next=/wsgi-scripts/admin/" --referer="${RFIDURL}" "${RFIDURL}auth/user/" > /dev/null 2>&1

# Grab RFID log file
#echo "- When prompted, enter local ssh key password:"
#ssh ${RFID_SSH_UNAME}@${RFIDHOST} -p 2222 "cat ${RFID_LOG}" > $RFIDTMP4
cp $RFID_LOG $RFIDTMP4

for line in `egrep "presented tag at reader|granted access" $RFIDTMP4 | awk '{print $1"~"$2"~"$11"~"$12"~"$NF}' | tr -d "'"`;do
#for line in `egrep "granted access" $RFIDTMP4 | awk '{print $1"~"$2"~"$11"~"$NF}' | tr -d "'"`;do
	myDATE=`echo $line | awk -F~ '{print $1}'`
	myTIME=`echo $line | awk -F~ '{print $2}'`
	myRFID=`echo $line | awk -F~ '{print $3}'` # CAREFUL!! Posting this to public html access exposes us to rfid cloning!
	myMESSAGE=`echo $line | awk -F~ '{print $4}'`
	myREADER=`echo $line | awk -F~ '{print $5}'`

	if [[ $myMESSAGE == "presented" ]];then
		printf "$myDATE $myTIME - Step1: RFID detected reader $myREADER  - " >> $OUT
		rfid_line=`awk -F\> '{print $18}' $RFIDTMP3 | grep -in $myRFID | awk -F: '{print $1}'`
		myNAME=`rfid_name_lookup $rfid_line`
		echo "$myNAME" >> $OUT
	else
		printf "$myDATE $myTIME - Step2: Granted access reader $myREADER - " >> $OUT
		rfid_line=`awk -F\> '{print $18}' $RFIDTMP3 | grep -in $myRFID | awk -F: '{print $1}'`
		myNAME=`rfid_name_lookup $rfid_line`
		echo "$myNAME" >> $OUT
	fi
	unset rfid_line myDATE myTIME
done

# Other access messages
#"presented tag at reader|granted access|denied access|successfully added|SAT Access Control System rebooted|SAT Priveleged"
for line in `egrep "denied access|successfully added" $RFIDTMP4 | awk '{print $1"~"$2"~"$11}'`;do
	myDATE=`echo $line | awk -F~ '{print $1}'`
	myTIME=`echo $line | awk -F~ '{print $2}'`
	myRFID=`echo $line | awk -F~ '{print $3}'`

	if [[ $myRFID == "denied" ]];then
		# Remember that in this case $myRFID contains only the word "denied"
		echo "$myDATE $myTIME - Denied access, unprogrammed RFID - n/a" >> $OUT
	else
		rfid_line=`awk -F\> '{print $18}' $RFIDTMP3 | grep -n $myRFID | awk -F: '{print $1}'`
		myNAME=`rfid_name_lookup $rfid_line`
		echo "$myDATE $myTIME - Successfully added - $myNAME" >> $OUT
	fi
	#echo "$myNAME" >> $OUT
	unset myDATE myTIME myRFID myNAME
done

# Users are locked out by setting their "mask" to 255. This is legitimate if an ex-member tries to use their fob (or their rfid is disabled do to being behind in dues).
# This is also an indicator that something could be out of sync between the arduino and the Django interface.
for line in `egrep "locked out" $RFIDTMP4 | awk '{print $1"~"$2"~"$7"~"$8"~"$9"~"$10}'`;do
	myDATE=`echo $line | awk -F~ '{print $1}'`
	myTIME=`echo $line | awk -F~ '{print $2}'`
	myMASK=`echo $line | awk -F~ '{print $3" "$4" "$5" "$6}'`

	#rfid_line=`awk -F\> '{print $18}' $RFIDTMP3 | grep -n $myRFID | awk -F: '{print $1}'`
	echo "$myDATE $myTIME - ${myMASK}" >> $OUT
	#echo "$myNAME" >> $OUT
	unset myDATE myTIME myMASK
done

# Exit button pressed
for line in `egrep "Exit button pressed" $RFIDTMP4 | awk '{print $1"~"$2"~"$7"~"$8"~"$9}'`;do
	myDATE=`echo $line | awk -F~ '{print $1}'`
	myTIME=`echo $line | awk -F~ '{print $2}'`
	myEXIT=`echo $line | awk -F~ '{print $3" "$4" "$5}' | tr -d "'."`

	#rfid_line=`awk -F\> '{print $18}' $RFIDTMP3 | grep -n $myRFID | awk -F: '{print $1}'`
	echo "$myDATE $myTIME - ${myEXIT}" >> $OUT
	#echo "$myNAME" >> $OUT
	unset myDATE myTIME myEXIT
done

# System messages (reboots, manual logins, etc.)
for line in `egrep "Access Control System rebooted|Priveleged mode" $RFIDTMP4 | awk '{print $1"~"$2"~"$10"~"$11"~"$12"~"$13}'`;do
	myDATE=`echo $line | awk -F~ '{print $1}'`
	myTIME=`echo $line | awk -F~ '{print $2}'`
	mym1=`echo $line | awk -F~ '{print $3}' | tr -d "'"`
	mym2=`echo $line | awk -F~ '{print $4}' | tr -d "'"`
	mym3=`echo $line | awk -F~ '{print $5}' | tr -d "'"`
	mym4=`echo $line | awk -F~ '{print $6}' | tr -d "'"`
	echo "$myDATE $myTIME - $mym1 $mym2 $mym3 $mym4" >> $OUT
done

if [[ -z $HTML ]];then
	sort -n $OUT
else
	echo "<html><head><title>Bloominglabs RFID Access Log</title></head><body><h1>Bloominglabs RFID Access Log</h1>`date`<hr>" > $HTMLOUT

	echo "<a href="/rfid/">Parent directory</a><pre>" >> $HTMLOUT
	sort -r -n $OUT >> $HTMLOUT
	echo "</pre></body></html>" >> $HTMLOUT
fi

cleanup

