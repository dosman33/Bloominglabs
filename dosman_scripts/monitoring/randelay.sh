#!/bin/bash
# 7-16-14 / NTH / delay a cron job by a random amount


rand() {
        #spits out a random number, requires an upper bound number as input
        typeset upper=$1
        RNUM=`awk -vu=$upper 'BEGIN {
                srand();
                printf( "%0.0f\n", rand() * u );
        }'`
        if [[ $RNUM -eq 0 ]];then
                ((RNUM=RNUM + 1))
        fi
        echo $RNUM
}

DELAY=`rand $1`
sleep $DELAY
$2 $3 $4 $5
