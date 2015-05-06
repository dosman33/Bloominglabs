#!/bin/bash
# 2015-02-12 / dosman / Snags still image from ESCAM IP camera using RTSP
#############################################################################

USER=admin
PASSWORD=
CAMIP=192.168.1.10
CAMPORT=554
OUTPATH=/var/www/cam1
OUTNAME=cam01.jpg
OUT="${OUTPATH}/${OUTNAME}"

#############################################################################

#ffmpeg -y -i rtsp://192.168.1.10:554//user=admin_password=_channel=1_stream=0.sdp -f image2 -vframes 1 /var/www/cam1/cam01.jpg

/usr/bin/ffmpeg -y -i rtsp://${CAMIP}:${CAMPORT}//user=${USER}_password=_channel=1_stream=0.sdp -f image2 -vframes 1 ${OUT}
